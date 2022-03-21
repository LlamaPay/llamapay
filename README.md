# LlamaPay

Automate salary txs, streaming them by the second so employees can withdraw whenever they want and you don't have to deal with sending txs manually.

Features:
- Easy top up for all streams in 1 operation
- Low gas
- Ability to trigger withdraws for someone else (for people that don't use metamask)
- Open source & verified contracts
- Fast UI
- Available on all chains
- No big precision errors
- Works with all tokens
- Deposits and withdrawals in 1 operation
- Works with debt, if you forget to pay on time we keep track of everything you missed
- No need to deposit all money at the start of the stream

Wishlist:
- Earn yield on idle money (I built a version with this under v2, but it's very complex so I won't deploy it)
- Privacy
- DCA with salary


## Gas costs
Cost to create a stream:
| Protocol | Cost (Gwei) |
|----------|-------------|
| LlamaPay | 74,104
| Sablier | 240,070
| SuperFluid | 279,992

So LlamaPay is 3.2x-3.7x cheaper than the competition!

## Debt
In superfluid, if you forget to top up your balance and the streams deplete all your balance, a bot will send a tx that will cancel all your streams, and takes part of your money, which you just lose. To get it working again you need to:
- Create all the streams from scratch again
- Calculate how much money payees have lost while the streams were down and send it to them manually
- Just accept the losses from the cancellations

This is not ideal because the whole reason you want this is to automate payments and the product should reduce your workload, not increase it like that.

With LlamaPay, when your balance gets depleted, all that happens is that the payer just starts incurring debt, and when there's a new deposit that debt is paid and streams keep working as usual. If the payer really meant to stop streams by just not depositing more, they can just not deposit any more (users will be able to withdraw the money they received up until the payer's balance was depleted), or cancel individual streams, which will remove their debt.

Payer never has the option to remove money that has already been streamed, once it has been streamed it can only be withdrawn to the payee's wallet. This makes it equivalent to superfluid's system from the POV of the payee, the only difference is that LlamaPay gives the option to the payer to just resume streams and repay debt easily, greatly simplifying the process in case they forgot or couldn't top up in time.

Superfluid bot: https://polygonscan.com/address/0x759999a81fade877fe91ed4c09db45ee50db2044

----

## Development

```shell
npm test
npx hardhat coverage
npx hardhat --network rinkeby deploy
npx hardhat --network rinkeby etherscan-verify
npx hardhat verify --network rinkeby DEPLOYED_CONTRACT_ADDRESS
```