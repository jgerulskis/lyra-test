# Lyra Test

This project is a test of the Lyra protocol. The Straddle contracts creates a straddle position on an options market. The position is created by buying a call and a put option with the same strike price and expiration date. The position is closed by selling the call and put option. The profit or loss is the difference between the premium paid and the premium received.

## TODO
The contract has a lot of things that could be elaborated on but sufficient for what I was trying to accomplish. The following are some of the things that could be added.

1. Close position
2. Expand functionality on the Custom Vault
3. Add access modifiers on Straddle so only the CustomVault can call the functions 
4. Optimize for gas
5. Write tests for all contracts instead of doing integration testing with scripts

## Setup
```shell
yarn
yarn run deploy:testSystem
yarn run deploy:straddle
```
