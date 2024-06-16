pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PPFXStargateDepositHook} from "../src/PPFXStargateDepositHook.sol";
import {PPFXStargateWithdrawHook} from "../src/PPFXStargateWithdrawHook.sol";
import {IPPFX} from "../src/IPPFX.sol";

contract HooksDeploymentScript is Script {

    struct HooksConfig {
        address ppfx;
        address admin;
        address treasury;
        address stargate;
        address lzEndpoint;
        address[] withdrawHookOperators;
    }

    HooksConfig config;

    function setUp() public {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/config/hooksConfig.json");
        string memory json = vm.readFile(path);
        
        address ppfx = vm.parseJsonAddress(json, ".ppfx");
        address admin = vm.parseJsonAddress(json, ".admin");
        address treasury = vm.parseJsonAddress(json, ".treasury");
        address stargate = vm.parseJsonAddress(json, ".stargate");
        address lzEndpoint = vm.parseJsonAddress(json, ".lzEndpoint");
        address[] memory operators = vm.parseJsonAddressArray(json, ".withdrawHookOperators");

        config = HooksConfig(
            ppfx,
            admin,
            treasury,
            stargate,
            lzEndpoint,
            operators
        );

        console.log("setUp() loaded config:");
        console.log("PPFX: %o", config.ppfx);
        console.log("PPFX USDT: %o", IPPFX(config.ppfx).usdt());
        console.log("Admin: %o", config.admin);
        console.log("Treasury: %o", config.treasury);
        console.log("Stargate: %o", config.stargate);
        console.log("LzEndpoint: %o", config.lzEndpoint);
    }

    function run() public {
        require(config.ppfx != address(0), "HooksDeployment: PPFX address can not be null");
        require(config.admin != address(0), "HooksDeployment: Admin address can not be null");
        require(config.treasury != address(0), "HooksDeployment: Treasury address can not be null");
        require(config.stargate != address(0), "HooksDeployment: Stargate address can not be null");
        require(config.lzEndpoint != address(0), "HooksDeployment: lzEndpoint address can not be null");

        vm.startBroadcast();
        
        PPFXStargateDepositHook depositHook = new PPFXStargateDepositHook(
            config.ppfx,
            config.lzEndpoint,
            config.stargate
        );
        
        PPFXStargateWithdrawHook withdrawHook = new PPFXStargateWithdrawHook(
            IPPFX(config.ppfx),
            config.admin,
            config.treasury,
            config.stargate
        );

        uint256 operatorsLen = config.withdrawHookOperators.length;

        if (operatorsLen > 0) {
            console.log("Start adding operators to deployed withdraw hook...");
            for (uint i = 0; i < operatorsLen; i ++) {
                address operatorAddr = config.withdrawHookOperators[i];
                if (!withdrawHook.isOperator(operatorAddr)) {
                    withdrawHook.addOperator(operatorAddr);
                    console.log("Added new operator:");
                    console.logAddress(operatorAddr);
                } else {
                    console.logAddress(operatorAddr);
                    console.log("already an operator");
                }
            }
        } else {
            console.log("No Operators Found in config");
        }

        console.log("=== Successfully Deployed & Setup Both Hooks ===");

        console.log("Deposit Hook Deployed at:");
        console.logAddress(address(depositHook));

        console.log("Withdraw Hook Deployed at:");
        console.logAddress(address(withdrawHook));

        console.log("\n\n");

        console.log("Withdraw Hook Operators:");
        address[] memory allOperators = withdrawHook.getAllOperators();
        for (uint i = 0; i < allOperators.length; i ++) {
            console.logAddress(allOperators[i]);
        }

        console.log("\n=== Setup PPFX: Update Withdraw Hook Address ===");
        IPPFX(config.ppfx).updateWithdrawHook(address(withdrawHook));

        vm.stopBroadcast();   
    }
}