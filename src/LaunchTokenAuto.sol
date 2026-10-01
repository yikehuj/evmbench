// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Pay {
    function transfer(address to, uint256 amount) external returns (bool);
}

// ERC20 that keeps an on-chain list of its real holders so the factory can PUSH paired-asset rewards
// to everyone in a single permissionless call — no per-holder claim. The v4 pool and the factory are
// excluded from the holder list so pooled/transient balances never receive rewards.
contract LaunchTokenAuto {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public launcher;
    address public pairedStock;
    string public description;
    string public image;
    string public website;
    string public twitter;
    bool private _initialized;

    address public constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address public feeManager;    // the launchpad factory
    address public rewardToken;   // == pairedStock
    bool public holdersShare;     // true => push to holders; false => dev-only

    mapping(address => bool) public excludedFromRewards;
    address[] public holderList;               // enumerable, real holders only
    mapping(address => uint256) public holderIndex; // 1-based; 0 = not a listed holder

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event RewardsPushed(uint256 amount, uint256 holders);

    function initialize(
        string calldata name_,
        string calldata symbol_,
        uint256 supply_,
        address to_,
        address pairedStock_,
        string calldata description_,
        string calldata image_,
        string calldata website_,
        string calldata twitter_,
        bool holdersShare_
    ) external {
        require(!_initialized, "initialized");
        _initialized = true;
        name = name_;
        symbol = symbol_;
        launcher = to_;
        pairedStock = pairedStock_;
        rewardToken = pairedStock_;
        feeManager = msg.sender;
        holdersShare = holdersShare_;
        description = description_;
        image = image_;
        website = website_;
        twitter = twitter_;

        excludedFromRewards[msg.sender] = true;   // factory
        excludedFromRewards[POOL_MANAGER] = true;  // the pool

        totalSupply = supply_;
        balanceOf[to_] = supply_; // to_ == factory == excluded
        emit Transfer(address(0), to_, supply_);
    }

    function meta() external view returns (string memory, string memory, string memory, string memory, address) {
        return (description, image, website, twitter, pairedStock);
    }

    function holderCount() external view returns (uint256) {
        return holderList.length;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        return _transfer(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) {
            require(a >= value, "allowance");
            allowance[from][msg.sender] = a - value;
        }
        return _transfer(from, to, value);
    }

    function _transfer(address from, address to, uint256 value) internal returns (bool) {
        require(to != address(0), "zero");
        uint256 bal = balanceOf[from];
        require(bal >= value, "balance");
        unchecked {
            balanceOf[from] = bal - value;
            balanceOf[to] += value;
        }
        _syncHolder(to);
        _syncHolder(from);
        emit Transfer(from, to, value);
        return true;
    }

    function _syncHolder(address a) internal {
        if (excludedFromRewards[a]) return;
        bool listed = holderIndex[a] != 0;
        if (balanceOf[a] > 0 && !listed) {
            holderList.push(a);
            holderIndex[a] = holderList.length;
        } else if (balanceOf[a] == 0 && listed) {
            uint256 idx = holderIndex[a];
            address last = holderList[holderList.length - 1];
            holderList[idx - 1] = last;
            holderIndex[last] = idx;
            holderList.pop();
            holderIndex[a] = 0;
        }
    }

    // Factory sends `amount` of rewardToken here then calls this: pay every listed holder pro-rata.
    // Permissionless trigger lives on the factory (harvest); this is factory-gated so funds are real.
    function pushDistribute(uint256 amount) external {
        require(msg.sender == feeManager, "manager");
        uint256 n = holderList.length;
        if (n == 0 || amount == 0) return;
        uint256 total;
        for (uint256 i; i < n; i++) total += balanceOf[holderList[i]];
        if (total == 0) return;
        for (uint256 i; i < n; i++) {
            address h = holderList[i];
            uint256 share = (amount * balanceOf[h]) / total;
            if (share > 0) IERC20Pay(rewardToken).transfer(h, share);
        }
        emit RewardsPushed(amount, n);
    }

    // Factory burns the launched-token side of collected fees (deflationary).
    function burn(uint256 amount) external {
        require(msg.sender == feeManager, "manager");
        uint256 bal = balanceOf[msg.sender];
        require(bal >= amount, "balance");
        unchecked {
            balanceOf[msg.sender] = bal - amount;
            totalSupply -= amount;
        }
        emit Transfer(msg.sender, address(0), amount);
    }
}
