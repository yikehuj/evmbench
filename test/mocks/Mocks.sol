// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import "permit2/interfaces/ISignatureTransfer.sol";

contract MockERC20 is ERC20 {
    uint8 private immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Minimal Uniswap V3 non-fungible position manager mock (no real pools needed).
contract MockNPM {
    struct Position {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        address owner;
    }

    mapping(uint256 => Position) internal positions_;

    uint256 public lastCollectTokenId;
    address public lastCollectRecipient;
    uint256 public collectCount;

    function factory() external view returns (address) {
        return address(this);
    }

    function WETH9() external pure returns (address) {
        return address(0);
    }

    function mint(address to, uint256 tokenId, address token0, address token1) external {
        positions_[tokenId] =
            Position(token0, token1, 3000, -887220, 887220, 1e18, 0, 0, to);
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return positions_[tokenId].owner;
    }

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position storage p = positions_[tokenId];
        return (
            0,
            address(0),
            p.token0,
            p.token1,
            p.fee,
            p.tickLower,
            p.tickUpper,
            p.liquidity,
            0,
            0,
            p.tokensOwed0,
            p.tokensOwed1
        );
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        _transfer(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        _transfer(from, to, tokenId, data);
    }

    function _transfer(address from, address to, uint256 tokenId, bytes memory data) internal {
        require(positions_[tokenId].owner == from, "MockNPM: not owner");
        positions_[tokenId].owner = to;
        if (to.code.length > 0) {
            require(
                IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data)
                    == IERC721Receiver.onERC721Received.selector,
                "MockNPM: unsafe recipient"
            );
        }
    }

    function decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams calldata params)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        positions_[params.tokenId].liquidity -= params.liquidity;
        return (0, 0);
    }

    function collect(INonfungiblePositionManager.CollectParams calldata params)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        lastCollectTokenId = params.tokenId;
        lastCollectRecipient = params.recipient;
        collectCount += 1;
        return (0, 0);
    }
}

contract MockOracle {
    mapping(uint256 => uint256) public value;
    address public immutable token0;
    address public immutable token1;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function setValue(uint256 tokenId, uint256 fullValue) external {
        value[tokenId] = fullValue;
    }

    function getValue(uint256 tokenId, address) external view returns (uint256, uint256, uint256, uint256) {
        uint256 v = value[tokenId];
        return (v, 0, uint256(2) ** 96, uint256(2) ** 96);
    }

    function getPositionBreakdown(uint256)
        external
        view
        returns (address, address, uint24, uint128, uint256, uint256, uint128, uint128)
    {
        return (token0, token1, 3000, 1e18, 0, 0, 0, 0);
    }
}

/// @dev Permit2 mock that pulls the token named in the permit (no signature verification).
contract MockPermit2 {
    using SafeERC20 for IERC20;

    function permitTransferFrom(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails calldata details,
        address owner,
        bytes calldata
    ) external {
        IERC20(permit.permitted.token).safeTransferFrom(owner, details.to, details.requestedAmount);
    }
}
