// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import "../src/TokenVault.sol";

contract DeployTokenVault is Script
{
    function run() external {
        // 从环境变量读取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);  // 开始广播交易
        TokenVault vault = new TokenVault();    // 部署TokenVault合约
        vm.stopBroadcast();                     // 停止广播
        
        console.log("Deploying from:", deployer);
        console.log("Balance:", deployer.balance);
        console.log("TokenVault deployed at:", address(vault));
    }
}
