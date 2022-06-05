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

## Why?
I used to handle payments by just sending transactions at the end of the month, however that soon turned into a pain and I started looking at alternatives that could automate it. Then I started using superfluid for that, and while the concept was great, there were many small execution problems that made using it very uncomfortable. Llamapay is my attempt at scratching my own itch, to build a system that exactly fits our needs at defillama, and, as I'm sure there's other teams that could benefit from it too, we plan to open source it and release it for everyone to use.

## Features

### Gas costs
Cost to create a stream:
| Protocol | Cost (gas) |
|----------|-------------|
| LlamaPay | 69,963
| Sablier | 240,070
| SuperFluid | 279,992

So LlamaPay is 3.2x-3.7x cheaper than the competition!

### No requirement on depositing all money needed for the stream
Sablier requires you to pick a duration for each stream and deposit all the money needed for the entirety of the stream at the start. This doesn't map well to salaries, since length is indeterminate.

This system forces you to keep creating new streams as the old ones die and you have to provide a large amount of capital that gets locked if you pick long durations. Instead a much better system is one where you create streams of indefinite duration and these just siphon money out of a pool, which makes it possible to top all streams up in a single operation and just provide money as it's needed to maintain them.

### Withdrawals that anyone can trigger
Some people will choose to provide an address that belongs to a CEX or a wallet that can't make ethereum calls. With current solutions this makes it impossible for them to claim their money, but llamapay allows anyone to trigger withdrawals, so it works in these cases too.

They can just set a CEX address and have someone else trigger withdrawals or trigger them themselves using another wallet. This greatly simplifies operations and possible problems.

### Available on all chains
After our public release, llamapay will be available on all EVM chains and all the contracts will share the same address across chains.

### No big precision errors
Sablier uses the same units as the underlying token when handling math for the stream. This means that for tokens that have a low number for decimals(), such as USDC, this causes precision errors. For example: if you stream 1000 USDC to an address, you'll instead end up streaming 997 USDC instead due to these errors.

LlamaPay operates internally with 20 decimals, which keep precision errors to a minimum.

### Works with all tokens
Using any token is very easy, which is not the case for superfluid.

### Debt
In superfluid, if you forget to top up your balance and the streams deplete all your balance, a bot will send a tx that will cancel all your streams, and takes part of your money, which you just lose. To get it working again you need to:
- Create all the streams from scratch again
- Calculate how much money payees have lost while the streams were down and send it to them manually
- Just accept the losses from the cancellations

This is not ideal because the whole reason you want this is to automate payments and the product should reduce your workload, not increase it like that.

With LlamaPay, when your balance gets depleted, all that happens is that the payer just starts incurring debt, and when there's a new deposit that debt is paid and streams keep working as usual. If the payer really meant to stop streams by just not depositing more, they can just not deposit any more (users will be able to withdraw the money they received up until the payer's balance was depleted), or cancel individual streams, which will remove their debt.

Payer never has the option to remove money that has already been streamed, once it has been streamed it can only be withdrawn to the payee's wallet. This makes it equivalent to superfluid's system from the POV of the payee, the only difference is that LlamaPay gives the option to the payer to just resume streams and repay debt easily, greatly simplifying the process in case they forgot or couldn't top up in time.

Superfluid bot: https://polygonscan.com/address/0x759999a81fade877fe91ed4c09db45ee50db2044


### Single-tx operations
Superfluid requires multiple operations for actions that are common (eg: withdraw money from a stream). LlamaPay simplifies these as maximum as possible and makes them available in a single tx.

## Roadmap
1. After UI is ready we'll deploy on mainnet and migrate all defillama payroll to it
2. We'll use it ourselves and modify anything we don't like
3. Remove rug code and release it publicly
4. Build v2

## V2
- Earn yield while money is being streamed (I built a version with this under v2, but it's very complex so we aren't deploying it)
- DCA with salary
- Positions as NFTs to enable payees to use that on defi (eg: pawn it to get payment advances)

Moonshots:
- Privacy though zero knowledge proofs

----

## Development

```shell
npm test
npx hardhat coverage
npx hardhat deploy --network rinkeby
npx hardhat etherscan-verify --network rinkeby
npx hardhat verify --network rinkeby DEPLOYED_CONTRACT_ADDRESS
```
