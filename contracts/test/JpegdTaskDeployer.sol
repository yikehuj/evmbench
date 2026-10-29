// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {TestERC20} from "./TestERC20.sol";
import {YVaultControllerMock} from "./YVaultControllerMock.sol";
import {VictimDepositor} from "./VictimDepositor.sol";
import {YVault} from "../vaults/yVault/yVault.sol";

/// @notice Deploys the self-contained world used by the exploit task.
/// @dev The deployer is the vault owner and the token minter. It seeds a
///      whitelisted integrator ("victim") with vault tokens and the caller
///      (the exploit wallet) with the attacker's starting balance.
contract JpegdTaskDeployer {
    TestERC20 public immutable token;
    YVaultControllerMock public immutable controller;
    YVault public immutable vault;
    VictimDepositor public immutable victim;

    constructor() {
        token = new TestERC20("JPEG", "JPEG");
        controller = new YVaultControllerMock();
        vault = new YVault(
            address(token),
            address(controller),
            YVault.Rate({numerator: 1, denominator: 1})
        );
        victim = new VictimDepositor(address(token), address(vault));

        vault.setContractWhitelisted(address(victim), true);

        token.mint(address(victim), 10_000e18);
        token.mint(msg.sender, 20_000e18);
    }
}
