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

```
npx hardhat --network rinkeby deploy
npx hardhat --network rinkeby etherscan-verify
```



This project demonstrates an advanced Hardhat use case, integrating other tools commonly used alongside Hardhat in the ecosystem.

The project comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts. It also comes with a variety of other tools, preconfigured to work with the project code.

Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
npx hardhat help
REPORT_GAS=true npx hardhat test
npx hardhat coverage
npx hardhat run scripts/deploy.ts
TS_NODE_FILES=true npx ts-node scripts/deploy.ts
npx eslint '**/*.{js,ts}'
npx eslint '**/*.{js,ts}' --fix
npx prettier '**/*.{json,sol,md}' --check
npx prettier '**/*.{json,sol,md}' --write
npx solhint 'contracts/**/*.sol'
npx solhint 'contracts/**/*.sol' --fix
```

# Etherscan verification

To try out Etherscan verification, you first need to deploy a contract to an Ethereum network that's supported by Etherscan, such as Ropsten.

In this project, copy the .env.example file to a file named .env, and then edit it to fill in the details. Enter your Etherscan API key, your Ropsten node URL (eg from Alchemy), and the private key of the account which will send the deployment transaction. With a valid .env file in place, first deploy your contract:

```shell
hardhat run --network ropsten scripts/deploy.ts
```

Then, copy the deployment address and paste it in to replace `DEPLOYED_CONTRACT_ADDRESS` in this command:

```shell
npx hardhat verify --network ropsten DEPLOYED_CONTRACT_ADDRESS "Hello, Hardhat!"
```

# Performance optimizations

For faster runs of your tests and scripts, consider skipping ts-node's type checking by setting the environment variable `TS_NODE_TRANSPILE_ONLY` to `1` in hardhat's environment. For more details see [the documentation](https://hardhat.org/guides/typescript.html#performance-optimizations).
