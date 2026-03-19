// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IRouterClient } from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { Client } from "@chainlink/contracts-ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import { OwnerIsCreator } from "@chainlink/contracts-ccip/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import { LinkTokenInterface } from "@chainlink/contracts-ccip/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

/**
 * 一个用于跨链发送字符串数据的简单合约。
 */
contract CrossChainCCIPSender is OwnerIsCreator
{
    // 余额不足时抛出的错误，包含当前余额和计算出的费用。
    // currentBalance : 合约当前持有的 LINK 余额。
    // calculatedFees : 发送消息所需的费用。
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);

    // 当消息发送到另一条链时触发的事件。
    // messageId : CCIP 消息的唯一 ID。
    // destinationChainSelector : 目标链的链选择器（chain selector）。
    // receiver : 目标链上接收方地址。
    // text : 发送的文本内容。
    // feeToken : 用于支付 CCIP 费用的代币地址。
    // fees : 发送 CCIP 消息所支付的费用。
    event MessageSent(bytes32 indexed messageId, uint64 indexed destinationChainSelector, address receiver, string text, address feeToken, uint256 fees);

    IRouterClient private s_router;
    LinkTokenInterface private s_linkToken;

    /// @notice 构造函数：使用 router 地址初始化合约。
    /// @param _router Router 合约地址。
    /// @param _link LINK 合约地址。
    constructor(address _router, address _link) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
    }

    /// @notice 向目标链上的接收方发送数据。
    /// @dev 假设你的合约持有足够的 LINK。
    /// @param destinationChainSelector 目标链的标识符（也称 selector）。
    /// @param receiver 目标链上的接收方地址。
    /// @param text 要发送的字符串文本。
    /// @return messageId 已发送消息的 ID。
    function sendMessage(uint64 destinationChainSelector, address receiver, string calldata text) external onlyOwner returns (bytes32 messageId) {
        // 在内存中创建 EVM2AnyMessage 结构体，填充跨链消息发送所需信息
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),               // ABI 编码后的接收方地址
            data: abi.encode(text),                       // ABI 编码后的字符串
            tokenAmounts: new Client.EVMTokenAmount[](0), // 空数组表示不发送任何代币
            extraArgs: Client._argsToBytes(
                // 额外参数：设置 gas 上限并允许乱序执行（out-of-order execution）。
                // 最佳实践：为简单起见这里使用硬编码。更推荐使用更动态的方式，在链下设置 extraArgs，
                // 以便根据不同的通道（lane）与消息进行调整，并确保兼容未来 CCIP 升级。更多信息：
                // https://docs.chain.link/ccip/concepts/best-practices/evm#using-extraargs
                Client.EVMExtraArgsV2({
                    gasLimit: 200_000,                    // 目标链回调执行的 gas 上限
                    allowOutOfOrderExecution: true        // 允许相对于同一发送方的其他消息乱序执行
                })
            ),
            feeToken: address(s_linkToken)  // 设置 feeToken 地址，表示使用 LINK 支付费用
        });

        // 获取发送该消息所需的费用
        uint256 fees = s_router.getFee(destinationChainSelector, evm2AnyMessage);
        if (fees > s_linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);
        }

        s_linkToken.approve(address(s_router), fees);   // 授权 Router 代表合约转移 LINK 代币；Router 将以 LINK 形式扣除费用
        messageId = s_router.ccipSend(destinationChainSelector, evm2AnyMessage);  // 通过 router 发送消息，并保存返回的消息 ID

        emit MessageSent(messageId, destinationChainSelector, receiver, text, address(s_linkToken), fees);

        return messageId; // 返回消息 ID
    }
}
