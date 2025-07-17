use core::starknet::ContractAddress;
use spherre::types::{Transaction, MemberDetails};

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
    /// Retrieves detailed metrics for a specific member
    ///
    /// # Parameters
    /// * `member` - The contract address of the member to get details for
    ///
    /// # Returns
    /// * `MemberDetails` A struct containing all member activity metrics
    ///
    /// # Panics
    /// * If the provided address is not a member
    fn get_member_full_details(self: @TContractState, member: ContractAddress) -> MemberDetails;
    /// Updates the smart will address for the caller
    ///
    /// # Parameters
    /// * `will_address` - The contract address to set as the will address
    ///
    /// # Panics
    /// * If caller is not a member
    /// * If will_address is a member
    /// * If will_address is already assigned to another member
    /// * If existing will duration has not elapsed
    fn update_smart_will(ref self: TContractState, will_address: ContractAddress);
    /// Gets the will address for a member
    ///
    /// # Parameters
    /// * `member` - The member's address to query
    ///
    /// # Returns
    /// * The will address for the member, or zero address if none set
    ///
    /// # Panics
    /// * If member address is not a member
    fn get_member_will_address(self: @TContractState, member: ContractAddress) -> ContractAddress;
    /// Gets the will duration for a member
    ///
    /// # Parameters
    /// * `member` - The member's address to query
    ///
    /// # Returns
    /// * The will duration in seconds, or 0 if no will is set
    ///
    /// # Panics
    /// * If member address is not a member
    fn get_member_will_duration(self: @TContractState, member: ContractAddress) -> u64;
    /// Gets the remaining time before a member can update their will
    ///
    /// # Parameters
    /// * `member` - The member's address to query
    ///
    /// # Returns
    /// * The remaining time in seconds, or 0 if will can be updated immediately
    ///
    /// # Panics
    /// * If member address is not a member
    fn get_remaining_will_time(self: @TContractState, member: ContractAddress) -> u64;
    /// Checks if a member can update their will
    ///
    /// # Parameters
    /// * `member` - The member's address to check
    ///
    /// # Returns
    /// * `bool` - True if member can update their will (no existing will or duration has elapsed),
    ///           false otherwise
    ///
    /// # Panics
    /// * If member address is not a member
    fn can_update_will(self: @TContractState, member: ContractAddress) -> bool;

     /// Resets the will duration for a member within the allowed reset window
    ///
    /// # Parameters
    /// * `member` - The member's address whose will duration should be reset
    ///
    /// # Panics
    /// * If the caller is not the member
    /// * If the member is not found
    /// * If the reset window is not active (not within 30 days before expiration)
    ///
    /// # Events
    /// * Emits a WillDurationReset event upon successful reset

    fn reset_will_duration(ref self: TContractState, member: ContractAddress);

    /// Fetch paginated list of transactions
    ///
    /// # Parameters
    /// * `start` - The start to fecth transaction
    /// * `limit` - The number of transaction to fetch from start
    ///
    /// # Returns
    /// * `Array` - List of transactions starting from the start index (if provided),
    ///              up to a maximum of limit transactions (if provided).
    ///
    /// # Panics
    /// * if start >= transaction count
    /// * if start + limit exceeds the transaction count
    fn transaction_list(
        self: @TContractState, start: Option<u64>, limit: Option<u64>
    ) -> Array<Transaction>;
}
