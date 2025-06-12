use core::starknet::ContractAddress;
use spherre::types::{Transaction};

/// Interface for managing account data in a smart contract
/// This interface defines methods for perfoming management operations related to Spherre account.
/// It includes methods for retrieving account members, transaction details, and account specific
/// details.

#[starknet::interface]
pub trait IAccountData<TContractState> {
    /// Retrieves the list of account members
    ///
    /// # Returns
    /// * `Array<ContractAddress>` An array of contract addresses representing the members of the
    /// account
    fn get_account_members(self: @TContractState) -> Array<ContractAddress>;
    /// Retrieves the count of members in the account
    ///
    /// # Returns
    /// * `u64` The number of members in the account
    fn get_members_count(self: @TContractState) -> u64;
    /// Retrieves the threshold for member actions
    ///
    /// # Returns
    /// * `(u64, u64)` A tuple containing the threshold and the total number of members
    fn get_threshold(self: @TContractState) -> (u64, u64);
    /// Retrieves a transaction by its ID
    ///
    /// # Parameters
    /// * `transaction_id` - The ID of the transaction to retrieve
    ///
    /// # Panics
    /// This function raises an error if the transaction is not found.
    ///
    /// # Returns
    /// * `Transaction` The transaction details associated with the given ID
    fn get_transaction(self: @TContractState, transaction_id: u256) -> Transaction;
    /// Checks if the address is a member of the account
    ///
    /// # Parameters
    /// * `address` - The contract address to check for membership
    ///
    /// # Returns
    /// * `bool` A boolean indicating whether the address is a member of the account
    fn is_member(self: @TContractState, address: ContractAddress) -> bool;
    /// Retrieves the number of voters in the account
    /// This function returns the count of members with voting permissions.
    /// The number of members that can approve and reject transactions.
    ///
    /// # Returns
    /// * `u64` The number of voters in the account
    fn get_number_of_voters(self: @TContractState) -> u64;
    /// Retrieves the number of proposers in the account
    /// This function returns the count of members with proposing permissions.
    /// The members that can propose new transactions.
    ///
    /// # Returns
    /// * `u64` The number of proposers in the account
    fn get_number_of_proposers(self: @TContractState) -> u64;
    /// Retrieves the number of executors in the account
    /// This function returns the count of members with execution permissions.
    /// The members that can finalize (execute) transactions.
    ///
    /// # Returns
    /// * `u64` The number of executors in the account
    fn get_number_of_executors(self: @TContractState) -> u64;
    /// Approves a transaction by its ID
    /// This function allows a member with voting permissions to approve a transaction.
    ///
    /// # Panics
    /// It raises an error if the transaction is not found or
    /// if the caller does not have permission to vote.
    /// It also raises an error if the contract is paused.
    /// It raises an error if the transaction is not in pending state.
    ///
    /// # Events
    /// It emits a TransactionApproved event upon successful approval.
    ///
    /// # Parameters
    /// * `tx_id` - The ID of the transaction to approve
    fn approve_transaction(ref self: TContractState, tx_id: u256);
    /// Rejects a transaction by its ID
    /// This function allows a member with voting permissions to reject a transaction.
    ///
    /// # Panics
    /// It raises an error if the transaction is not found or
    /// if the caller does not have permission to vote.
    /// It also raises an error if the contract is paused.
    /// It raises an error if the transaction is not in pending state.
    ///
    /// # Events
    /// It emits a TransactionRejected event upon successful rejection.
    ///
    /// # Parameters
    /// * `tx_id` - The ID of the transaction to reject
    fn reject_transaction(ref self: TContractState, tx_id: u256);
}
