# Smart CryptoCurrency Bank Account

```
This exercise is done to complete quest#1, #2 and #3 in the Questbook, as per the link below. 
```
https://questbook.notion.site/Track-Writing-code-in-Solidity-Begin-Here-0cdfb112506d45c58e72bc3425e8684a

The main features of the smart cryptocurrency bank account are as below:

* **addBalance**: User can deposit amount in ETH to the smart contract which will then be deposited to Compound to earn interest

* **addBalanceERC20**: User can deposit any ERC20 token which will then be swapped into ETH and deposited to Compound to earn interest. This function is formed of 3 main steps: 
  * **addTokens**: User will transfer the approved amount of ERC20 token to this contract
  * **swapExactTokensforETH**: The contract will swap ERC20 tokens into ETH via UniswapV2Router 
  * **depositToCompound**: The contract will deposit ETH to Compound to earn interest
  
* **withdraw**: User can withdraw amount in ETH + interest rate earned from Compound. User will specify the amount that they wish to withdraw, and the function will require that the amount that can be withdrawn should be less then the amount deposited + interest earned from Compound.

* **withdrawInERC20**: User can withdraw amount equivalent to ETH + interest rate in any ERC20 token. User will specify the amount that they wish to withdraw and in which ERC20 token. The function will require that the amount that can be withdrawn should be less than the amount deposited + interest earned from Compound.

