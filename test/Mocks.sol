// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev Minimal ERC20 used as the vault asset. `revertOnZeroApprove` lets a test
/// model tokens that revert when an allowance is reset to zero.
contract SmokeToken {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    bool public revertOnZeroApprove;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function setRevertOnZeroApprove(bool _value) external {
        revertOnZeroApprove = _value;
    }

    function mint(address _to, uint256 _amount) external {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        if (revertOnZeroApprove && _amount == 0) revert("ZERO_APPROVAL");
        allowance[msg.sender][_spender] = _amount;
        return true;
    }

    function transfer(address _to, uint256 _amount) external returns (bool) {
        balanceOf[msg.sender] -= _amount;
        balanceOf[_to] += _amount;
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        uint256 allowed = allowance[_from][msg.sender];
        if (allowed != type(uint256).max) allowance[_from][msg.sender] = allowed - _amount;
        balanceOf[_from] -= _amount;
        balanceOf[_to] += _amount;
        return true;
    }
}

/// @dev Minimal ERC4626 market with a configurable `maxDeposit` and a yield
/// accrual hook (`accrue`) that raises the value of existing shares.
contract SmokeMarket {
    SmokeToken public asset;
    uint256 public maxDepositCap;
    uint256 public totalShares;
    uint256 public totalAssetsHeld;

    mapping(address => uint256) public balanceOf;

    constructor(SmokeToken _asset, uint256 _maxDepositCap) {
        asset = _asset;
        maxDepositCap = _maxDepositCap;
    }

    function setMaxDeposit(uint256 _maxDepositCap) external {
        maxDepositCap = _maxDepositCap;
    }

    function accrue(uint256 _assets) external {
        totalAssetsHeld += _assets;
    }

    function maxDeposit(address) external view returns (uint256) {
        return maxDepositCap;
    }

    function previewDeposit(uint256 _assets) public view returns (uint256) {
        if (totalShares == 0) return _assets;
        return _assets * totalShares / totalAssetsHeld;
    }

    function previewRedeem(uint256 _shares) public view returns (uint256) {
        if (totalShares == 0) return 0;
        return _shares * totalAssetsHeld / totalShares;
    }

    function deposit(uint256 _assets, address _receiver) external returns (uint256 shares) {
        require(_assets <= maxDepositCap, "MAX_DEPOSIT");
        shares = previewDeposit(_assets);
        require(shares != 0, "ZERO_SHARES");
        asset.transferFrom(msg.sender, address(this), _assets);
        totalAssetsHeld += _assets;
        totalShares += shares;
        balanceOf[_receiver] += shares;
    }

    function maxWithdraw(address _owner) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return balanceOf[_owner] * totalAssetsHeld / totalShares;
    }

    function withdraw(uint256 _assets, address _receiver, address _owner) external returns (uint256 shares) {
        shares = totalAssetsHeld == 0 ? 0 : _assets * totalShares / totalAssetsHeld;
        balanceOf[_owner] -= shares;
        totalShares -= shares;
        totalAssetsHeld -= _assets;
        asset.transfer(_receiver, _assets);
    }
}

/// @dev Minimal IVaultIncentivesModule with no logics and no receivers.
contract SmokeIncentivesModule {
    function getAllIncentivesClaimingLogics() external pure returns (address[] memory logics) {
        logics = new address[](0);
    }

    function getNotificationReceivers() external pure returns (address[] memory receivers) {
        receivers = new address[](0);
    }
}

