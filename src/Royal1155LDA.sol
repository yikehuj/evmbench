// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Royal1155LDA — minimal faithful reproduction of the vulnerable ERC-1155
// "LDA" (Limited Digital Asset) token contract (real impl
// 0xd5b297c08d890376b6cbdba6023a39ffbdf65c78, v0.8.4, proxied).
//
// On top of a standard ERC-1155 balance, the contract maintains a *custom*
// per-tier ownership count (`_BALANCES_[tierId][account]`) that the Royalties
// payout contract trusts as the source of pro-rata royalty ownership.
//
// The vulnerable line is `_beforeTokenTransfer`: it loops over `ids[]` and
// increments the receiver's tier balance once per entry WITHOUT ever checking
// `amounts[i]`. A batch transfer that moves zero ERC-1155 tokens (amounts all
// zero) therefore still credits the receiver with tier ownership — the custom
// tier balance diverges from the canonical ERC-1155 balance.
//
// Simplifications vs. the on-chain implementation (none touch the vulnerability):
//   - a single flat contract (the real one is a proxy + upgradeable OZ base);
//   - LDA IDs map to a tier via a direct `idToTier` mapping instead of the
//     bit-packed `tierId/version/tokenId` decomposition;
//   - the `_OWNED_TOKENS_`/`_OWNERS_` enumerations and the royalty transfer
//     hook (`beforeLdaTransfer`) are dropped — the vulnerability is fully
//     captured by the amount-unaware `_BALANCES_[tierId][to]` increment;
//   - permit / pausable / access-control / extras machinery dropped.

contract Royal1155LDA {
    // Canonical ERC-1155 balances.
    mapping(uint256 => mapping(address => uint256)) internal _balances;

    // Custom per-tier ownership count (what Royalties trusts).
    mapping(uint128 => mapping(address => uint256)) internal _BALANCES_;

    // LDA ID -> tier ID.
    mapping(uint256 => uint128) public idToTier;

    // Tier supply bookkeeping.
    mapping(uint128 => uint256) public tierMaxSupply;
    mapping(uint128 => uint256) public tierCurrentSupply;

    // Operator approval (ERC-1155).
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    address public owner;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }

    // ---- ERC-1155 surface --------------------------------------------------

    function balanceOf(address account, uint256 id) public view returns (uint256) {
        return _balances[id][account];
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i; i < accounts.length; i++) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) external {
        require(msg.sender != operator, "self approval");
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external {
        require(from == msg.sender || isApprovedForAll[from][msg.sender], "not owner nor approved");
        require(to != address(0), "to zero");
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = id;
        amounts[0] = amount;
        _beforeTokenTransfer(msg.sender, from, to, ids, amounts, data);
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "insufficient balance");
        unchecked { _balances[id][from] = fromBalance - amount; }
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external {
        require(from == msg.sender || isApprovedForAll[from][msg.sender], "not owner nor approved");
        require(to != address(0), "to zero");
        require(ids.length == amounts.length, "length mismatch");

        // The hook runs BEFORE the canonical ERC-1155 balance update, exactly
        // as in the real contract, so its side effects happen even for a batch
        // whose canonical balances never change.
        _beforeTokenTransfer(msg.sender, from, to, ids, amounts, data);

        for (uint256 i; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "insufficient balance");
            unchecked { _balances[id][from] = fromBalance - amount; }
            _balances[id][to] += amount;
        }
        emit TransferBatch(msg.sender, from, to, ids, amounts);
    }

    // ---- tier accounting (the vulnerable hook) ------------------------------

    /// @notice Overridable transfer hook, invoked before every single/batch
    /// transfer and mint. The vulnerable behaviour: the `to`-side tier balance
    /// is incremented once per id entry regardless of the transferred amount.
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        for (uint256 i; i < ids.length; i++) {
            uint256 ldaId = ids[i];
            uint128 tierId = idToTier[ldaId];

            // Self-transfer: skip everything that follows.
            if (from == to) {
                continue;
            }

            // Token leaves a wallet: decrement the custom tier balance.
            if (from != address(0)) {
                uint256 balance = _BALANCES_[tierId][from];
                if (balance != 0) {
                    _BALANCES_[tierId][from] = balance - 1;
                }
            }

            // Token enters a wallet: increment the custom tier balance.
            // VULNERABILITY: runs even when amounts[i] == 0.
            if (to != address(0)) {
                _BALANCES_[tierId][to] = _BALANCES_[tierId][to] + 1;
            }
        }
    }

    // ---- tier queries (Royalties trusts tierBalanceOf) -----------------------

    function tierBalanceOf(uint128 tierId, address account) external view returns (uint256) {
        return _BALANCES_[tierId][account];
    }

    function getTierTotalSupply(uint128 tierId) external view returns (uint256) {
        return tierMaxSupply[tierId];
    }

    // ---- owner-only seeding -------------------------------------------------

    function createTier(uint128 tierId, uint256 maxSupply) external onlyOwner {
        require(tierId != 0 && maxSupply != 0, "invalid tier");
        require(tierMaxSupply[tierId] == 0, "tier exists");
        tierMaxSupply[tierId] = maxSupply;
    }

    function mintLDA(address recipient, uint256 ldaId, uint128 tierId) external onlyOwner {
        require(tierId != 0, "invalid tier");
        require(idToTier[ldaId] == 0, "already minted");
        require(tierMaxSupply[tierId] != 0, "tier does not exist");
        require(tierCurrentSupply[tierId] < tierMaxSupply[tierId], "tier exhausted");
        idToTier[ldaId] = tierId;
        tierCurrentSupply[tierId] += 1;
        _mint(recipient, ldaId, 1, "");
    }

    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal {
        require(to != address(0), "to zero");
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        ids[0] = id;
        amounts[0] = amount;
        _beforeTokenTransfer(msg.sender, address(0), to, ids, amounts, data);
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }
}
