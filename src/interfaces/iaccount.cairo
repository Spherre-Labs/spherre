use core::byte_array::ByteArray;
use spherre::types::AccountDetails;
use starknet::{ContractAddress};

/// Interface for the SpherreAccount contract
/// This interface defines the entrypoints of the SpherreAccount contract.
/// It includes methods for retrieving account details, managing the account state
/// and interacting with the account.

#[starknet::interface]
pub trait IAccount<TContractState> {
    /// Retrieves the name of the account
    ///
    /// # Returns
    /// * `ByteArray` The name of the account as a byte array
    fn get_name(self: @TContractState) -> ByteArray;
    /// Retrieves the description of the account
    ///
    /// # Returns
    /// * `ByteArray` The description of the account as a byte array
    fn get_description(self: @TContractState) -> ByteArray;
    /// Retrieves the account details
    ///
    /// # Returns
    /// * `AccountDetails` The details of the account.
    fn get_account_details(self: @TContractState) -> AccountDetails;
    /// Retrieves the deployer of the account
    ///
    /// # Returns
    /// * `ContractAddress` The address of the account manager (the deployer).
    fn get_deployer(self: @TContractState) -> ContractAddress;
    /// Pauses the account contract
    ///
    /// # Panics
    /// This function raises an error if the caller is not the deployer.
    fn pause(ref self: TContractState);
    /// Unpauses the account contract
    ///
    /// # Panics
    /// This function raises an error if the caller is not the deployer.
    fn unpause(ref self: TContractState);
    /// Executes a transaction by its ID
    ///
    /// # Parameters
    /// * `transaction_id` - The ID of the transaction to execute.
    /// # Panics
    /// This function raises an error if the transaction is not executable.
    ///
    fn execute_transaction(ref self: TContractState, transaction_id: u256,);
}
