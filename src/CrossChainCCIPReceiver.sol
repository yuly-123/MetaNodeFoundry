// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CCIPReceiver } from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import { Client } from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

/**
 * 一个用于跨链接收字符串数据的简单合约。
 */
contract CrossChainCCIPReceiver is CCIPReceiver
{
    // 当从另一条链接收到消息时触发的事件。
    // messageId : CCIP 消息的唯一 ID。
    // sourceChainSelector : 源链的链选择器（chain selector）。
    // sender : 源链上发送方地址。
    // text : 接收到的文本内容。
    event MessageReceived(bytes32 indexed messageId, uint64 indexed sourceChainSelector, address sender, string text);

    bytes32 private s_lastReceivedMessageId;    // 保存最近一次接收到的 messageId。
    string private s_lastReceivedText;          // 保存最近一次接收到的文本。

    /// @notice 构造函数：使用 router 地址初始化合约。
    /// @param router Router 合约地址。
    constructor(address router) CCIPReceiver(router) {}

    /// 处理收到的消息
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
        s_lastReceivedMessageId = any2EvmMessage.messageId;             // 获取 messageId
        s_lastReceivedText = abi.decode(any2EvmMessage.data, (string)); // 对发送的文本进行 ABI 解码

        emit MessageReceived(
            s_lastReceivedMessageId,
            any2EvmMessage.sourceChainSelector,           // 获取源链标识符（也称 selector）
            abi.decode(any2EvmMessage.sender, (address)), // 对发送方地址进行 ABI 解码
            s_lastReceivedText
        );
    }

    /// @notice 获取最近一次接收到的消息详情。
    /// @return messageId 最近一次接收到的 messageId。
    /// @return text 最近一次接收到的文本。
    function getLastReceivedMessageDetails() external view returns (bytes32 messageId, string memory text) {
        return (s_lastReceivedMessageId, s_lastReceivedText);
    }
}
