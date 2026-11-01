// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC2981} from "openzeppelin/interfaces/IERC2981.sol";

/// @notice Minimal mintable ERC721 used by the packaged tests.
contract MockNFT is ERC721 {
    constructor() ERC721("Mock NFT", "MNFT") {}

    function mint(address to, uint256 id) external {
        _mint(to, id);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }
}

/// @notice Minimal mintable ERC20 with configurable decimals.
contract MockERC20 is ERC20 {
    constructor(uint8 decimals_) ERC20("Mock Token", "MCK", decimals_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Royalty registry stub that resolves every NFT to itself.
contract MockRoyaltyRegistry {
    function getRoyaltyLookupAddress(address nft) external pure returns (address) {
        return nft;
    }
}

/// @notice ERC721 that also answers ERC2981 royalty queries. The royalty can be
/// switched from a static numerator to "full sale price" by calling bump(),
/// which models an attacker-controlled royalty that changes mid-transaction.
contract RoyaltyNFT is ERC721 {
    address public recipient;
    uint256 public feeNumerator; // out of 1e18
    bool public full;

    constructor() ERC721("Royalty NFT", "RNFT") {}

    function mint(address to, uint256 id) external {
        _mint(to, id);
    }

    function configure(address recipient_, uint256 feeNumerator_) external {
        recipient = recipient_;
        feeNumerator = feeNumerator_;
    }

    function bump() external {
        full = true;
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function royaltyInfo(uint256, uint256 salePrice) external view returns (address, uint256) {
        if (full) return (recipient, salePrice);
        return (recipient, (salePrice * feeNumerator) / 1e18);
    }
}

/// @notice ERC721 that reverts if setApprovalForAll is called twice with the same
/// operator for the same owner, mirroring ERC721 implementations that revert on
/// redundant approvals.
contract StrictApprovalNFT is ERC721 {
    error AlreadyApproved();

    mapping(address => mapping(address => bool)) private _approved;

    constructor() ERC721("Strict NFT", "SNFT") {}

    function mint(address to, uint256 id) external {
        _mint(to, id);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }

    function setApprovalForAll(address operator, bool approved) public override {
        if (approved && _approved[msg.sender][operator]) revert AlreadyApproved();
        _approved[msg.sender][operator] = approved;
        super.setApprovalForAll(operator, approved);
    }
}

/// @notice Metadata stub that happily returns a URI for any token id.
contract MockMetadata {
    function tokenURI(uint256) external pure returns (string memory) {
        return "https://example.invalid/fake";
    }
}
