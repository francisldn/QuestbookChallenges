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

interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

}

// File: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol

pragma solidity >=0.6.2;

interface IUniswapV2Router02 is IUniswapV2Router01 {

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


contract SmartBankAccount {


    uint public totalContractBalance;
    //rinkeby = 0xd6801a1dffcd0a410336ef88def4320d6df1883e
    //ropsten = 0x859e9d8a4edadfedb5a2ff311243af80f85a91b8
    address COMPOUND_CETH_ADDRESS = 0xd6801a1DfFCd0a410336Ef88DeF4320D6DF1883e;
    cETH ceth = cETH(COMPOUND_CETH_ADDRESS);

    address UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 uniswap = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    address internal weth = uniswap.WETH();
    
    uint public depositAmountInETH;
    uint public transferAmountERC20;
    uint internal depositAmountInCeth;
    uint internal totalAmountInCeth;

    uint public redeemed;
    uint public erc20TokenRedeemed;

    mapping(address => uint) balances;
    // mapping(address => uint) depositTimestamps;
    
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
    
    // This function allows user to deposit ERC20 tokens to this contract
    // this contract is formed of 3 functions - addTokens, swapExactTokensforETH and depositToCompound
    function addBalanceERC20(address erc20TokenAddress) public payable {
        // dai token address on ropsten: 0xad6d458402f60fd3bd25163575031acdce07538d
        // dai token address on rinkeby: 0xc7ad46e0b8a400bb3c915120d284aafba8fc4735
        IERC20 erc20 = IERC20(erc20TokenAddress);
        
        //reset depositAmountInETH to 0
        depositAmountInETH =0;
        // get approval outside of smart contract first
        addTokens(erc20TokenAddress);
        
        uint depositTokens = erc20.balanceOf(address(this));
        depositAmountInETH = swapExactTokensforETH(erc20TokenAddress, depositTokens);

        // deposit amount to this contract
        balances[msg.sender] += depositAmountInETH;
        totalContractBalance += depositAmountInETH;
        
        depositToCompound();
    }
    
    // this function allows user to deposit ETH available in this contract to Compound
    function depositToCompound() public payable {
        require(address(this).balance >0, "no ETH to deposit");
        
        depositAmountInCeth = 0;
        uint cethBalanceBefore = ceth.balanceOf(address(this));
        ceth.mint{value: address(this).balance}();
        uint cethBalanceAfter = ceth.balanceOf(address(this));
        depositAmountInCeth = cethBalanceAfter- cethBalanceBefore; 
    }
    
    // this function enables user to deposit erc20 tokens to this contract after user has approved the amount
    function addTokens (address erc20TokenAddress) public payable {
        IERC20 erc20 = IERC20(erc20TokenAddress);
        
        transferAmountERC20 =0;
        require(erc20.allowance(msg.sender, address(this))>0, "increase transfer allowance");
        // user will have to approve the ERC20 token amount outside of the smart contract
        uint depositTokens = erc20.allowance(msg.sender, address(this));
        erc20.transferFrom(msg.sender, address(this), depositTokens);
        // this is added for sanity check
        transferAmountERC20 = erc20.balanceOf(address(this));
    }
    
    // this function is to check the amount that has been approved by user
    function getAllowanceERC20(address erc20TokenAddress) public view returns (uint) {
        IERC20 erc20 = IERC20(erc20TokenAddress);
        return erc20.allowance(msg.sender, address(this));
    }
    
    // this function enables the contract to convert erc20 tokens into ETH to be deposited to Compound
    function swapExactTokensforETH(address erc20TokenAddress, uint swapAmount) public payable returns (uint) {
        IERC20 erc20 = IERC20(erc20TokenAddress);
        require(erc20.balanceOf(address(this))>0, "insufficient tokens to swap");
        
        erc20.approve(address(uniswap),swapAmount);
        uint allowedAmount = erc20.allowance(address(this), address(uniswap));
        
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = erc20TokenAddress;
        path[1] = weth;
        
        depositAmountInETH = 0;
        uint ETHBalanceBeforeSwap = address(this).balance;
        // make the swap
        uniswap.swapExactTokensForETH(
            allowedAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        
        uint ETHBalanceAfterSwap = address(this).balance;
        depositAmountInETH = ETHBalanceAfterSwap - ETHBalanceBeforeSwap;
        return depositAmountInETH;
    }

    function swapExactETHForTokens(address erc20TokenAddress, uint swapAmountInWei) public payable returns (uint) {
        IERC20 erc20 = IERC20(erc20TokenAddress);
        require(address(this).balance>0, "insufficient ETH to swap");
        
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = erc20TokenAddress;
        
        uint erc20TokenAmount = 0;
        uint erc20TokenBeforeSwap = erc20.balanceOf(address(this));
        uniswap.swapExactETHForTokens{value: swapAmountInWei}(
            0, // accept any amount of token
            path,
            address(this),
            block.timestamp
        );
        uint erc20TokenAfterSwap = erc20.balanceOf(address(this));
        erc20TokenAmount = erc20TokenAfterSwap - erc20TokenBeforeSwap;
        return erc20TokenAmount;
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
    
    function withdrawInERC20 (uint _withdrawAmountInWei, address erc20TokenAddress) public payable returns (uint) {
        IERC20 erc20 = IERC20(erc20TokenAddress);
        
        require(_withdrawAmountInWei <= getBalanceInWei(msg.sender), "overdrawn");
        
        redeemed =0;
        erc20TokenRedeemed =0;
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
        
        // convert the amount redeemed to ERC20 token
        erc20TokenRedeemed = swapExactETHForTokens(erc20TokenAddress,redeemed);
        bool sent = erc20.transfer(msg.sender, erc20TokenRedeemed);
        require(sent, "Failed to send token");
        return erc20TokenRedeemed;
    }
    
    receive() external payable {
    }
    
}
