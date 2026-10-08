interface VmSign { function sign(uint256,bytes32) external view returns (uint8,bytes32,bytes32); }
pragma solidity ^0.8.23;
import {Scenario} from "../src/Scenario.sol";
import {LegendaryMoneyMonNft} from "../src/LegendaryMoneyMonNft.sol";
import {SeededMON} from "../src/SeededMON.sol";

/// @notice Legitimate-behavior smoke tests that must hold on the unfixed
///         baseline and after the reference fix alike.
contract ExistingSmoke {
    VmSign constant VM = VmSign(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 constant ADMIN_KEY = 0xA11CE;

    /// The fixture deploys the NFT reward contract with a seeded MON treasury.
    function testScenarioDeploysSeededRewardPool() public {
        Scenario s = new Scenario();
        assert(address(s.nft()) != address(0));
        assert(address(s.mon()) != address(0));
        assert(s.VICTIM() == 0xaCc0c1f672B03B9a5fED4535f840f09B85f40E98);
        assert(s.nft().owner() == address(this));
        assert(s.nft().admin() == address(0));
        assert(s.mon().totalSupply() == 100000 ether);
        assert(s.mon().balanceOf(address(s.nft())) == 100000 ether);
        assert(s.mon().balanceOf(address(this)) == 0);
    }

    /// Once an admin is registered, a genuinely signed reward claim is
    /// verified and paid out of the seeded treasury.
    function testSignedClaimPaysRewardFromTreasury() public {
        Scenario s = new Scenario();
        LegendaryMoneyMonNft nft = s.nft();
        SeededMON mon = s.mon();
        _setAdmin(nft);
        bytes memory sig = _claimSig(
            address(nft), address(mon), address(this), 1, 10 ether, block.timestamp, "mon"
        );
        assert(nft.verify(address(mon), address(this), 1, 10 ether, block.timestamp, "mon", sig));
        nft.cliamRewred(address(mon), 10 ether, 1, block.timestamp, "mon", sig);
        assert(mon.balanceOf(address(this)) == 10 ether);
        assert(mon.balanceOf(address(nft)) == 100000 ether - 10 ether);
    }

    /// Once an admin is registered, an all-zero (unsigned) claim is rejected
    /// and pays nothing, on the baseline and after the fix alike.
    function testForgedClaimRejectedWhenAdminSet() public {
        Scenario s = new Scenario();
        LegendaryMoneyMonNft nft = s.nft();
        _setAdmin(nft);
        bytes memory forged = new bytes(65);
        forged[64] = bytes1(uint8(27));
        assert(
            !nft.verify(address(s.mon()), address(this), 1, 10 ether, block.timestamp, "mon", forged)
        );
        (bool ok, ) = address(nft).call(
            abi.encodeWithSignature(
                "cliamRewred(address,uint256,uint256,uint256,string,bytes)",
                address(s.mon()), 10 ether, 1, block.timestamp, "mon", forged
            )
        );
        assert(!ok);
        assert(s.mon().balanceOf(address(this)) == 0);
        assert(s.mon().balanceOf(address(nft)) == 100000 ether);
    }

    /// Registers the ecrecover address of ADMIN_KEY as the reward admin.
    function _setAdmin(LegendaryMoneyMonNft nft) internal {
        bytes32 probe = keccak256("moneymon-admin");
        (uint8 v, bytes32 r, bytes32 s) = VM.sign(ADMIN_KEY, probe);
        address admin = ecrecover(probe, v, r, s);
        assert(admin != address(0));
        nft.changeadmin(admin);
        assert(nft.admin() == admin);
    }

    /// Signs a claim exactly the way verify() hashes it.
    function _claimSig(
        address nftAddr,
        address payment,
        address user,
        uint256 nftid,
        uint256 amount,
        uint256 time,
        string memory exname
    ) internal view returns (bytes memory sig) {
        bytes32 prefixed = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(nftAddr, payment, user, nftid, amount, time, exname))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = VM.sign(ADMIN_KEY, prefixed);
        sig = abi.encodePacked(r, s, v);
    }
}
