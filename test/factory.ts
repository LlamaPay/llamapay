import { expect } from "chai";
import { ethers } from "hardhat";
import {deployAll} from './utils'

describe("Factory", function () {
  it("can't create the an instance for the same token twice", async function () {
    const { llamaPay, llamaPayFactory, token } = await deployAll({})
    await expect(
      llamaPayFactory.createPayContract(token.address)
    ).to.be.revertedWith("already exists");
  });

  it("array works", async function () {
    let tokens = [
      "0xdac17f958d2ee523a2206206994597c13d831ec7",
      "0xB8c77482e45F1F44dE1745F52C74426C631bDD52",
      "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
      "0x2b591e99afe9f32eaa6214f7b7629768c40eeb39"
    ]
    const { llamaPay, llamaPayFactory, token } = await deployAll({});
    for(const tokenAddress of tokens){
      expect(await llamaPayFactory.payContracts(tokenAddress)).to.equal("0x0000000000000000000000000000000000000000")
      await llamaPayFactory.createPayContract(tokenAddress);
    }
    expect(await llamaPayFactory.payContractsArrayLength()).to.equal((tokens.length+1).toString())
    tokens = [token.address].concat(tokens)
    for(let i =0; i<tokens.length; i++){
      expect(await llamaPayFactory.payContractsArray(i)).not.to.equal("0x0000000000000000000000000000000000000000");
      expect(await llamaPayFactory.payContracts(tokens[i])).not.to.equal("0x0000000000000000000000000000000000000000")
    }
  });

  it("owner, and only owner, can rug", async ()=>{
    const { llamaPay, llamaPayFactory, token } = await deployAll({});
    const [owner, attacker] = await ethers.getSigners();
    const amount = "100"
    await token.transfer(llamaPay.address, amount)
    expect(await token.balanceOf(llamaPay.address)).to.equal(amount);
    await expect(
      llamaPay.connect(attacker).emergencyRug(owner.address, "10")
    ).to.be.revertedWith("not owner");
    await llamaPay.connect(owner).emergencyRug(owner.address, "10")
    expect(await token.balanceOf(llamaPay.address)).to.equal("90");
    await llamaPay.connect(owner).emergencyRug(owner.address, "0")
    expect(await token.balanceOf(llamaPay.address)).to.equal("0");
  })
});
