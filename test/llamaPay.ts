import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { deployAll } from './utils'

const MONTH = 24 * 3600 * 30

async function basicSetup(){
    const { llamaPay, token } = await deployAll({})
    const [payer, payee, payee2] = await ethers.getSigners();
    await token.approve(llamaPay.address, BigNumber.from(2).pow(256).sub(1))
    const DECIMALS_DIVISOR = await llamaPay.DECIMALS_DIVISOR()
    return {llamaPay, DECIMALS_DIVISOR, payee, payee2, token}
}

async function advanceTime(time:number){
    await ethers.provider.send("evm_increaseTime", [time])
}

async function setupStream(monthlyTotal:number, decimals:number=18) {
    const { llamaPay, token } = await deployAll({
        tokenDecimals: decimals
    })
    const [payer, payee, payee2] = await ethers.getSigners();
    await token.approve(llamaPay.address, "999999999999999999999999999999999")
    const DECIMALS_DIVISOR = await llamaPay.DECIMALS_DIVISOR()
    const monthlySalary = BigNumber.from(10).pow(decimals).mul(monthlyTotal)
    const perSec = monthlySalary.mul(DECIMALS_DIVISOR).div(MONTH)
    await llamaPay.createStream(payee.address, perSec)
    await llamaPay.deposit(monthlySalary.mul(2))
    await advanceTime(MONTH-1)
    return {token, payee, llamaPay, payer, perSec, payee2}
}

async function setupStreamAndWithdraw(monthlyTotal:number, decimals:number){
    const {llamaPay, payee, perSec, payer, token} = await setupStream(monthlyTotal, decimals)
    await llamaPay.withdraw(payer.address, payee.address, perSec);
    const totalPaid = await token.balanceOf(payee.address)
    return {totalPaid}
}

function bg(n:number){
    return BigNumber.from(n.toLocaleString(undefined, {
        style: 'decimal',
        useGrouping: false //Flip to true if you want to include commas
      }))
}

async function balanceIs(token:any, address:string, balance:number){
    sameNum(await token.balanceOf(address), balance)
}

function sameNum(n1:any, n2:number, precision:number=2){
    expect((n1/1e18).toFixed(precision)).to.equal(n2.toFixed(precision))
}

const decimalsPrecision = 5

describe("LlamaPay", function () {
    it("works with tokens with 20 decimals but doesn't on tokens with >20 decimals", async function () {
        await setupStream(1e6, 20)
        await expect(setupStream(1e6, 21)).to.be.revertedWith("")
    })
    it("there's no big precision errors when the token has high decimals (18)", async function () {
        const {totalPaid} = await setupStreamAndWithdraw(1e6, 18)
        expect((totalPaid/10**18).toFixed(decimalsPrecision)).to.equal((1e6).toFixed(decimalsPrecision))
    });
    it("there's no big precision errors when the token has low decimals (6)", async function () {
        const {totalPaid} = await setupStreamAndWithdraw(1e3, 6)
        expect((totalPaid/10**6).toFixed(decimalsPrecision)).to.equal(1e3.toFixed(decimalsPrecision))
    });
    it("can't withdraw on a cancelled stream", async ()=>{
        const {payer, payee, llamaPay, perSec} = await setupStream(5e3);
        await llamaPay.cancelStream(payee.address, perSec)
        await expect(llamaPay.withdraw(payer.address, payee.address, perSec)).to.be.revertedWith("stream doesn't exist");
    })
    it("withdrawPayer works and if withdraw is called after less than perSec funds are left in contract", async ()=>{
        const {payer, payee, llamaPay, token, perSec} = await setupStream(10e3);
        await llamaPay.withdrawPayer(5e3*1e3);
        const left = await llamaPay.getPayerBalance(payer.address)
        expect(left).to.be.gt(bg(9.9999e3*1e18));
        await llamaPay.withdrawPayerAll();
        const left2 = await llamaPay.getPayerBalance(payer.address)
        expect(left2).to.be.lt("0"); // negative because some seconds have gone since withdrawal
        expect(left2).to.be.gt(perSec.mul(-1));
        await llamaPay.withdraw(payer.address, payee.address, perSec);
        expect(await token.balanceOf(llamaPay.address)).to.be.lt(perSec)
    })
    it("if withdrawPayer is called after stream withdrawal then almost no tokens are left in contract", async ()=>{
        const {payer, payee, llamaPay, token, perSec} = await setupStream(10e3);
        await llamaPay.cancelStream(payee.address, perSec)
        await llamaPay.withdrawPayerAll();
        expect(await token.balanceOf(llamaPay.address)).to.equal("0")
    })
    it("modifyStream", async ()=>{
        const {payer, payee, llamaPay, perSec, payee2} = await setupStream(10e3);
        const streamId = await llamaPay.getStreamId(payer.address, payee.address, perSec);
        const statusBefore = await llamaPay.streamToStart(streamId)
        expect(statusBefore).not.to.eq("0")
        await llamaPay.modifyStream(payee.address, perSec, payee2.address, 20);
        const statusAfter = await llamaPay.streamToStart(streamId)
        expect(statusAfter).to.eq("0")
    })
    it("standard flow with multiple payees and payers", async ()=>{
        const {llamaPay, token, DECIMALS_DIVISOR} = await basicSetup();
        const [owner, payer, payee, payee2] = await ethers.getSigners();
        const total = bg(10e3*1e18) // 10k
        await token.transfer(payer.address, total.mul(10))
        await token.connect(payer).approve(llamaPay.address, total.mul(10))
        const monthly1k = total.div(10).div(MONTH).mul(DECIMALS_DIVISOR) // 1k
        await llamaPay.connect(payer).depositAndCreate(total, payee.address, monthly1k.mul(5)) // 10k deposited
        await advanceTime(MONTH/2) // 2.5k paid
        await llamaPay.connect(payer).createStream(payee2.address, monthly1k.mul(10)) // 10k
        await llamaPay.connect(payee2).withdraw(payer.address, payee.address, monthly1k.mul(5))
        await balanceIs(token, payee.address, 2.5e3);
        await advanceTime(MONTH) // 7.5k + 10k paid
        await llamaPay.withdraw(payer.address, payee.address, monthly1k.mul(5)) // can only withdraw up to 2.5k
        await balanceIs(token, payee.address, 5e3);
        await llamaPay.withdraw(payer.address, payee2.address, monthly1k.mul(10))
        await balanceIs(token, payee2.address, 5e3);

        // attempt withdrawal again
        const prevBal = await token.balanceOf(payee.address);
        await llamaPay.withdraw(payer.address, payee.address, monthly1k.mul(5))
        const afterBal = await token.balanceOf(payee.address);

        expect(prevBal).to.equal(afterBal);
        // payer tries to steal by creating a new stream while in debt
        // Can't create new streams until debt is paid
        expect(llamaPay.connect(payer).createStream(payee2.address, monthly1k.mul(100))).to.be.revertedWith("aaaa")
        // Can't withdraw if there's debt
        expect(llamaPay.connect(payer).withdrawPayer("1")).to.be.revertedWith("aaaa")
        const payerBal = await llamaPay.getPayerBalance(payer.address)
        sameNum(payerBal, -7.5e3, 1); // 7.5k owed
        const withdrawable1 = await llamaPay.withdrawable(payer.address, payee2.address, monthly1k.mul(10))
        expect(withdrawable1.withdrawableAmount).to.eq(0)
        sameNum(withdrawable1.owed, 5e3, 1)

        await llamaPay.connect(payer).deposit(bg(1e3*1e18))
        const withdrawable2 = await llamaPay.withdrawable(payer.address, payee2.address, monthly1k.mul(10))
        sameNum(withdrawable2.withdrawableAmount, 666.6666, 1)
        sameNum(withdrawable2.owed, 4.333333e3, 0)

        const withdrawablePayee1 = await llamaPay.withdrawable(payer.address, payee.address, monthly1k.mul(5))
        sameNum(withdrawablePayee1.withdrawableAmount, 333.333, 1)
        sameNum(withdrawablePayee1.owed, 2.5e3-333.3, 0)

        // payer rugs first payee by cancelling their stream
        await llamaPay.connect(payer).cancelStream(payee.address, monthly1k.mul(5))
        await balanceIs(token, payee.address, 5e3+333.33);
        expect(llamaPay.withdraw(payer.address, payee.address, monthly1k.mul(5))).to.be.revertedWith("aaaa") // can't withdraw from stream anymore
        const withdrawablePayee2AfterCancel = await llamaPay.withdrawable(payer.address, payee2.address, monthly1k.mul(10))
        sameNum(withdrawablePayee2AfterCancel.owed, Number(withdrawable2.owed)/1e18, 1)

        // extra debt from payee 2 is cancelled
        sameNum(await llamaPay.getPayerBalance(payer.address), -4.333e3, 0);

        await llamaPay.connect(payer).deposit(bg(10e3*1e18)) // payer deposits 10k
        sameNum(await llamaPay.getPayerBalance(payer.address), 5.66666e3, 0); // 7.5k owed

        const withdrawablePayee2Again = await llamaPay.withdrawable(payer.address, payee2.address, monthly1k.mul(10))
        sameNum(withdrawablePayee2Again.withdrawableAmount, 5e3, 0);

        await llamaPay.withdraw(payer.address, payee2.address, monthly1k.mul(10))
        await balanceIs(token, payee2.address, 10000.04);
    })
    it("overflow triggered on totalPaidPerSec", async ()=>{
        const {payee, llamaPay, payee2} = await basicSetup();
        const perSecOverflow = BigNumber.from(2).pow(216).sub(5);
        await llamaPay.deposit(perSecOverflow.mul(10))
        await llamaPay.createStream(payee.address, perSecOverflow)
        await llamaPay.createStream(payee2.address, "1")
        await llamaPay.createStream(payee2.address, "2")
        await expect(llamaPay.createStream(payee2.address, "5")).to.be.revertedWith("");
    })
    it("can't overwrite stream", async ()=>{
        const {payee, llamaPay} = await basicSetup();
        const perSec = "100000000000"
        llamaPay.createStream(payee.address, perSec)
        await expect(llamaPay.createStream(payee.address, perSec)).to.be.revertedWith("stream already exists");
    })
    it("can't create stream with 0 payment", async ()=>{
        const {payee, llamaPay} = await basicSetup();
        await expect(llamaPay.createStream(payee.address, "0")).to.be.revertedWith("amountPerSec can't be 0");
    })
    it("can't cancel non-existent stream", async ()=>{
        const {payee, llamaPay} = await basicSetup();
        await expect(llamaPay.cancelStream(payee.address, "1")).to.be.revertedWith("stream doesn't exist");
    })
})