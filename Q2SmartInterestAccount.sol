//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;


interface cETH {
    
    // define functions of COMPOUND we'll be using
    
    function mint() external payable; // to deposit to compound
    function mint(uint mintAmount) external payable returns (uint);
    function redeem(uint redeemTokens) external returns (uint); // to withdraw from compound
    
    //following 2 functions to determine how much you'll be able to withdraw
    function exchangeRateStored() external view returns (uint); 
    function balanceOf(address owner) external view returns (uint256 balance);
}


contract SmartBankAccount {


    uint public totalContractBalance;
    //rinkeby = 0xd6801a1dffcd0a410336ef88def4320d6df1883e
    //ropsten = 0x859e9d8a4edadfedb5a2ff311243af80f85a91b8
    address COMPOUND_CETH_ADDRESS = 0xd6801a1DfFCd0a410336Ef88DeF4320D6DF1883e;
    cETH ceth = cETH(COMPOUND_CETH_ADDRESS);

    uint public depositAmountInETH;
    uint internal depositAmountInCeth;
    uint internal totalAmountInCeth;

    uint public redeemed;

    mapping(address => uint) balances;
    
    function addBalance() public payable {
        balances[msg.sender] += msg.value;
        totalContractBalance += msg.value;
        
        //send ethers to mint()
        ceth.mint{value: msg.value}();
    }
    
    // get the total amount deposited to this contract by various users
    function getContractBalance() public view returns(uint){
        return totalContractBalance;
    }
    
    // get the total amount deposited to Compound from this contract converted to wei
    function getCompoundBalance() internal view returns (uint) {
        return ceth.balanceOf(address(this))*ceth.exchangeRateStored()/1e18;
    }
    
    // get total amount of Ceth held by this contract
    function getTotalCethAmount() internal view returns (uint) {
        return ceth.balanceOf(address(this));
    }
    
    // to calculate the conversion rate between amount deposited to this contract and amount available at Compound
    // note the decimal handling - 1e18 has to be placed in the numerator before dividing by getContractBalance
    function conversionRateCompToContract() internal view returns (uint) {
        return getCompoundBalance()*1e18/getContractBalance();
    }
    
    function conversionRateContractToCeth() internal view returns (uint) {
        return getContractBalance()/getTotalCethAmount();
    }
    
    
    // amount expressed in wei
    function getBalanceInWei(address userAddress) public view returns(uint256) {
        return getCethBalanceInWei() * balances[userAddress]/totalContractBalance;
    }
    
    // amount expressed in wei
    function getCethBalanceInWei () internal view returns (uint256) {
        return ceth.balanceOf(address(this))*ceth.exchangeRateStored()/1e18;
    }

    function withdraw(uint _withdrawAmountInWei) public payable returns (uint) {
        // check that the withdraw amount is less than the user's balance
        require(_withdrawAmountInWei <= getBalanceInWei(msg.sender), "overdrawn");
        
        redeemed = 0;
        // convert amount to Ceth so that this contract can redeem from Compound
        uint amountToRedeemInCeth = (_withdrawAmountInWei*1e18/conversionRateCompToContract())/conversionRateContractToCeth();
        uint amountToRedeem = (_withdrawAmountInWei/conversionRateCompToContract())/1e18;
        balances[msg.sender] -= amountToRedeem;
        totalContractBalance -= amountToRedeem;
        
        
        // record the amount before redeem
        uint contractBalanceBeforeRedeem = address(this).balance;
        
        ceth.redeem(amountToRedeemInCeth);
        
        // record the amount after redeem
        uint contractBalanceAfterRedeem = address(this).balance;
        
        redeemed = contractBalanceAfterRedeem - contractBalanceBeforeRedeem;
        
        (bool sent,) = payable(msg.sender).call{value: redeemed}("");
        require(sent, "Failed to send ether");
        return redeemed;
    }
    
    receive() external payable {
    }
    
}
