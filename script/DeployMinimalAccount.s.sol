// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {NetworkConfig, HelperConfig} from "script/HelperConfig.s.sol";

contract DeployMinimalAccount is Script {
    function run() public {
        deployMinimalAccount();
    }

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        HelperConfig helperConfig = new HelperConfig();
        NetworkConfig memory cfg = helperConfig.getConfig();

        vm.startBroadcast(cfg.account);
        MinimalAccount minimalAccount = new MinimalAccount(cfg.entryPoint);
        minimalAccount.transferOwnership(cfg.account);
        vm.stopBroadcast();
        return (helperConfig, minimalAccount);
    }
}
