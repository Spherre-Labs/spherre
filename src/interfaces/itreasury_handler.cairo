use spherre::types::SmartTokenLock;
use starknet::ContractAddress;

/// Interface for the TreasuryHandler component
/// This interface defines the entrypoints of the TreasuryHandler component.
/// It includes methods for querying ERC-20 balances and ERC-721 ownership.

#[starknet::interface]
pub trait ITreasuryHandler<TContractState> {
    /// Returns the ERC‑20 token balance for this account.
    ///
    /// # Parameters
    /// - `token_address` – The ERC‑20 token contract address.
    ///
    /// # Returns
    /// - `u256` – The token balance owned by the account.
    fn get_token_balance(self: @TContractState, token_address: ContractAddress) -> u256;

    /// Checks if this account owns a specific ERC‑721 token.
    ///
    /// # Parameters
    /// - `nft_address` – The ERC‑721 token contract address.
    /// - `token_id`    – The token identifier.
    ///
    /// # Returns
    /// * `bool` - Returns `true` if the account owns the specified token, `false` otherwise.
    fn is_nft_owner(self: @TContractState, nft_address: ContractAddress, token_id: u256) -> bool;

    /// Returns all locked plans.
    ///
    /// # Returns
    /// - `Array<SmartTokenLock>` – An array of all smart token lock plans.
    fn get_all_locked_plans(self: @TContractState) -> Array<SmartTokenLock>;

    /// Returns a specific locked plan by ID.
    ///
    /// # Parameters
    /// - `lock_id` – The unique lock identifier.
    ///
    /// # Returns
    /// - `SmartTokenLock` – The smart token lock plan.
    fn get_locked_plan_by_id(self: @TContractState, lock_id: u256) -> SmartTokenLock;
}
