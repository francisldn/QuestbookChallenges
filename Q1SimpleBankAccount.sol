//SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.0 <0.9.0;

contract SimpleBankAccount {

    uint totalContractBalance = 0;

    function getContractBalance() public view returns(uint){
        return totalContractBalance;
    }
    
    mapping(address => uint) balances;
    mapping(address => uint) depositTimestamps;
    
    // This function allows user to deposit amount into this smart contract 
    function addBalance() public payable returns (bool) {
        balances[msg.sender] = msg.value;
        totalContractBalance = totalContractBalance + msg.value;
        depositTimestamps[msg.sender] = block.timestamp;

        return true;
    }
    
    function getBalance(address userAddress) public view returns(uint) {
        uint principal = balances[userAddress];
        uint timeElapsed = block.timestamp - depositTimestamps[userAddress]; //seconds
        return principal + uint((principal * 7 * timeElapsed) / (100 * 365 * 24 * 60 * 60)); //simple interest of 7%  per year
    }
    
    function withdraw() public payable returns (bool) {
        address payable withdrawTo = payable(msg.sender);
        uint amountToTransfer = getBalance(msg.sender);
        balances[msg.sender] = 0;
        totalContractBalance = totalContractBalance - amountToTransfer;
        (bool sent,) = withdrawTo.call{value: amountToTransfer}("");
        require(sent, "transfer failed");
        
        return true;
    }
    
    function addMoneyToContract() public payable {
        totalContractBalance += msg.value;
    }

    receive() external payable {
    }
}