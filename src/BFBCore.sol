// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;



// safe transfer
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        // (bool success,) = to.call.value(value)(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}


// Interface of the ERC20 standard as defined in the EIP.
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address from, address to) external view returns (uint256);
    function approve(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}


interface IPancakeRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
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


// owner
abstract contract Ownable2Step {
    address public owner;
    address public pendingOwner;


    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Ownable2Step: owner error');
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        pendingOwner = newOwner;
    }

    function acceptOwnership() public {
        require(pendingOwner != address(0), 'Ownable2Step: pengding owner inexistence');
        require(msg.sender == pendingOwner, 'Ownable2Step: pending owner error');
        owner = pendingOwner;
        delete pendingOwner;
    }

    // take eth.
    function takeETH(address to, uint256 amount) public onlyOwner {
        require(to != address(0), 'Ownable2Step: zero address error');
        require(amount > 0, 'Ownable2Step: value zero error');
        TransferHelper.safeTransferETH(to, amount);
    }

    // take token.
    function takeToken(address token, address to , uint256 amount) public onlyOwner {
        require(to != address(0), 'Ownable2Step: zero address error');
        require(amount > 0, 'Ownable2Step: value zero error');
        TransferHelper.safeTransfer(token, to, amount);
    }
}


interface ICore {
    function mySuper(address user) external view returns (address);
    function myJuniorsArr(address user) external view returns (address[] memory);
    function myJuniorCount(address user) external view returns (uint256);
    function checkoutBound(address myAddress, address superAddress) external view returns(bool);
    function boundSuper(address myAddress, address superAddress) external returns(bool);
    function buyAndBonus(address account) external payable;
    function whetherFilter(address account) external view returns(bool);
}


// BFB Core.
contract BFBCore is ICore, Ownable2Step {
    mapping(address => address) public mySuper;       // 上级
    mapping(address => address[]) public myJuniors;   // 直推地址数组
    mapping(address => uint256) public myJuniorCount; // 直推数量
    address[] public filterSpecialAddressArr;         // 过滤绑定关系的地址数组
    address public Token_Address;  // 本项目的token.
    address public Router_Address;
    address public WBNB_Address;
    address public WBNB_Token_LP_Address; // WBNB和token的LP
    address public Return_Address; // 计算残留的币，退回到某个地址
    uint256 public minLP = 1;
    uint256 private constant DENOMINATOR = 10000;
    uint256[8] public bonusArrRate = [1000,600,400,500,400,300,47,6000]; //leader1,leader2,leader3, super1,super2,super3,super4-20，user.
    address public leader1;
    address public leader2;
    address public leader3;
    uint256 public Min_BNB = 1e17;
    uint256 public Max_BNB = 1e18;
    mapping(address => bool) public whiteList;      // 只有白名单才可以参与
    bool public whiteListOpen = true;               // 白名单验证开关，开启就是需要验证白名单，关闭就是不需要验证白名单。
    uint256 public everydayLimit = 1e19;            // 每天的限制
    mapping(uint256 => uint256) public dayBNBCount; // 每天的累计




    event BoundSuper(address callerAddress, address myAddress, address superAddress);
    event BuyAndBonus(address senderAddress, address account, uint256 BNBAmount);
    

    constructor() {
        Token_Address = address(msg.sender);
        WBNB_Token_LP_Address = address(msg.sender);
        Return_Address = address(msg.sender);
        Router_Address = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        WBNB_Address = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

        leader1 = address(0x752eA706F6cED454f918C0f04571fE6da0cD992B);
        leader2 = address(0xfF7BfA137B606A5E7C0cf35264D8FA5930d8518a);
        leader3 = address(0xa8fc833C7016503Fa83189961129e63906004981);
        
        addFilterSpecialAddressArr(address(0));
        addFilterSpecialAddressArr(address(this));
        addFilterSpecialAddressArr(Router_Address);
    }
    

    modifier onlyTokenAddress() {
        require(msg.sender == Token_Address, 'Core: sender error');
        _;
    }

    function getBonusArrRate() external view returns(uint256[8] memory) {
        return bonusArrRate;
    }

    function setBonusArrRate(uint256[8] memory bonusArrRate_) external onlyOwner {
        delete bonusArrRate;
        bonusArrRate = bonusArrRate_;
    }

    function getFilterSpecialAddressArr() external view returns(address[] memory) {
        return filterSpecialAddressArr;
    }

    function addFilterSpecialAddressArr(address specialAddress) public onlyOwner {
        bool whetherExist;
        for(uint256 i; i < filterSpecialAddressArr.length; i++) {
            if(specialAddress == filterSpecialAddressArr[i]) whetherExist = true;
        }
        if(!whetherExist) filterSpecialAddressArr.push(specialAddress);
    }

    function removeFilterSpecialAddressArr(address specialAddress) external onlyOwner {
        address[] memory temporary = filterSpecialAddressArr;
        delete filterSpecialAddressArr;
        
        for(uint256 i; i < temporary.length; i++) {
            if(temporary[i] != specialAddress) filterSpecialAddressArr.push(temporary[i]);
        }
    }

    function whetherFilter(address account) external view returns(bool) {
        for(uint256 i; i < filterSpecialAddressArr.length; i++) {
            if(account == filterSpecialAddressArr[i]) return true; // 是排除的地址
        }
        return false;
    }
    

    function checkoutBound(address myAddress, address superAddress) public view returns(bool) {
        if(mySuper[myAddress] != address(0)) return false;  // 已经有上级了
        if(myAddress == superAddress) return false;         // 不能绑定自己
        for(uint256 i; i < filterSpecialAddressArr.length; i++) {
            if(myAddress == filterSpecialAddressArr[i] || superAddress == filterSpecialAddressArr[i]) return false; // 不能绑定特殊地址
        }

        address _s = mySuper[superAddress];
        // 如果循环是3，那么至少要5个地址才会闭环。也就是地址5才能绑定地址1。
        for(uint256 i; i < 20; i++) {
            // 不能闭环绑定
            if(_s == myAddress) return false; 
            _s = mySuper[_s];
        }
        return true;
    }

    function boundSuper(address myAddress, address superAddress) external onlyTokenAddress returns(bool) {
        require(checkoutBound(myAddress, superAddress), 'Core: checkout error');
        
        mySuper[myAddress] = superAddress;
        myJuniors[superAddress].push(myAddress);
        myJuniorCount[superAddress]++;
        emit BoundSuper(msg.sender, myAddress, superAddress);
        return true;
    }

    function myJuniorsArr(address user) external view override returns (address[] memory) {
        return myJuniors[user];
    }

    // 进行购买再分红
    function buyAndBonus(address account) external payable onlyTokenAddress {
        require(account != address(0), 'account is zero');
        // 分配BNB
        uint256 BNBValue = msg.value;
        require(BNBValue >= Min_BNB && BNBValue <= Max_BNB, 'BNB amount error');
        require(!whiteListOpen || whiteList[account], 'not white list');
        if(whiteList[account]) whiteList[account] = false;
        dayBNBCount[block.timestamp/86400] += BNBValue;
        require(dayBNBCount[block.timestamp/86400] <= everydayLimit, 'limit error');

        TransferHelper.safeTransferETH(leader1, BNBValue * bonusArrRate[0] / DENOMINATOR);
        TransferHelper.safeTransferETH(leader2, BNBValue * bonusArrRate[1] / DENOMINATOR);
        TransferHelper.safeTransferETH(leader3, BNBValue * bonusArrRate[2] / DENOMINATOR);
        address[] memory superArr = new address[](20);
        address superVar = account;
        for(uint256 i; i < 20; i++) {
            superVar = mySuper[superVar];
            superArr[i] = superVar;
        }
        for(uint256 i; i < superArr.length; i++) {
            address superAccount = superArr[i];
            uint256 superJuniorCount = myJuniorCount[superAccount];
            if((superJuniorCount >= 3 || superJuniorCount > i) && superAccount != address(0) && IERC20(WBNB_Token_LP_Address).balanceOf(superAccount) >= minLP) {
                if(i == 0) {
                    TransferHelper.safeTransferETH(superAccount, BNBValue * bonusArrRate[3] / DENOMINATOR);
                }else if(i == 1) {
                    TransferHelper.safeTransferETH(superAccount, BNBValue * bonusArrRate[4] / DENOMINATOR);
                }else if(i == 2) {
                    TransferHelper.safeTransferETH(superAccount, BNBValue * bonusArrRate[5] / DENOMINATOR);
                }else {
                    TransferHelper.safeTransferETH(superAccount, BNBValue * bonusArrRate[6] / DENOMINATOR);
                }
            }
        }

        // 先兑换token, 在添加池子
        // 允许除不尽，小数点后取整的情况。
        uint256 beforeBalance = IERC20(Token_Address).balanceOf(address(this));
        uint256 addBNBAmount = BNBValue * bonusArrRate[7] / DENOMINATOR / 2;
        address[] memory path = new address[](2);
        path[0] = WBNB_Address;
        path[1] = Token_Address;
        IPancakeRouter02(Router_Address).swapExactETHForTokens{value: addBNBAmount}(
            0,
            path,
            address(this),
            block.timestamp
        );
        uint256 lastBalance = IERC20(Token_Address).balanceOf(address(this));
        uint256 tokenAmount = lastBalance - beforeBalance;
        require(tokenAmount > 0, 'zero token');
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = IPancakeRouter02(Router_Address).addLiquidityETH{value: addBNBAmount}(Token_Address, tokenAmount, 0, 0, address(this), block.timestamp);
        require(liquidity > 0, 'zero lp');
        if(tokenAmount > amountToken) TransferHelper.safeTransfer(Token_Address, Return_Address, tokenAmount - amountToken);
        if(addBNBAmount > amountETH) TransferHelper.safeTransferETH(account, addBNBAmount - amountETH);
        TransferHelper.safeTransfer(WBNB_Token_LP_Address, account, liquidity);

        emit BuyAndBonus(msg.sender, account, BNBValue);
    }

    function setOther(address Token_Address_, address Router_Address_, address WBNB_Address_, address WBNB_Token_LP_Address_, address Return_Address_) external onlyOwner {
        require(Token_Address_ != address(0), 'error 1');
        require(Router_Address_ != address(0), 'error 2');
        require(WBNB_Address_ != address(0), 'error 3');
        require(WBNB_Token_LP_Address_ != address(0), 'error 4');
        require(Return_Address_ != address(0), 'error 5');

        Token_Address = Token_Address_;
        Router_Address = Router_Address_;
        WBNB_Address = WBNB_Address_;
        WBNB_Token_LP_Address = WBNB_Token_LP_Address_;
        Return_Address = Return_Address_;
        TransferHelper.safeApprove(Token_Address, Router_Address, ~uint256(0));
    }

    function setLeader(address leader1_, address leader2_, address leader3_) external onlyOwner {
        require(leader1_ != address(0), 'error 1');
        require(leader2_ != address(0), 'error 2');
        require(leader3_ != address(0), 'error 3');

        leader1 = leader1_;
        leader2 = leader2_;
        leader3 = leader3_;
    }

    function setMinLP(uint256 minLP_) external onlyOwner {
        minLP = minLP_;
    }

    function setBNBLimit(uint256 Min_BNB_, uint256 Max_BNB_, uint256 everydayLimit_, bool whiteListOpen_) external onlyOwner {
        require(Min_BNB_ > 0, 'min error');
        require(Max_BNB_ > Min_BNB_, 'max error');
        require(everydayLimit_ > Max_BNB_, 'limit error');
        Min_BNB = Min_BNB_;
        Max_BNB = Max_BNB_;
        everydayLimit = everydayLimit_;
        whiteListOpen = whiteListOpen_;
    }
    
    function addWhiteLists(address[] memory accounts) external onlyOwner {
        uint256 len = accounts.length;
        for(uint256 i; i < len; i++) {
            whiteList[accounts[i]] = true;
        }
    }

    function removeWhiteLists(address[] memory accounts) external onlyOwner {
        uint256 len = accounts.length;
        for(uint256 i; i < len; i++) {
            whiteList[accounts[i]] = false;
        }
    }
    
    receive() external payable {}
    
}