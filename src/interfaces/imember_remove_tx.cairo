use spherre::types::MemberRemoveData;
use starknet::ContractAddress;

/// Interface for the MemberRemoveTransaction component
/// This interface defines the entrypoints of the MemberRemoveTransaction component.
/// It includes methods for proposing, retrieving, and executing member removal transactions.

#[starknet::interface]
pub trait IMemberRemoveTransaction<TContractState> {
    /// Proposes a new member removal transaction
    /// This function allows a member with the proposer permission to propose removing a member
    /// from the account.
    ///
    /// # Parameters
    /// * `member_address` - The contract address of the member to be removed.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the proposer permission.
    /// This function raises an error if the member address is not a member of the account.
    /// This function raises an error if the member address is the zero address.
    fn propose_remove_member_transaction(
        ref self: TContractState, member_address: ContractAddress
    ) -> u256;
    /// Retrieves a member removal transaction by its ID
    /// This function allows retrieval of a specific member removal transaction
    /// by its unique identifier.
    ///
    /// # Parameters
    /// * `transaction_id` - The ID of the member removal transaction to retrieve.
    ///
    /// # Panics
    /// This function raises an error if the transaction with the given ID does not exist.
    /// This function raises an error if the transaction is not a member removal transaction.
    ///
    /// # Returns
    /// * `MemberRemoveData` The details of the member removal transaction.
    fn get_member_removal_transaction(
        self: @TContractState, transaction_id: u256
    ) -> MemberRemoveData;
    /// Retrieves all member removal transactions
    /// This function returns a list of all member removal transactions that have been created.
    ///
    /// # Returns
    /// * `Array<MemberRemoveData>` An array of all member removal transactions.
    fn member_removal_transaction_list(self: @TContractState) -> Array<MemberRemoveData>;
    /// Executes a member removal transaction
    /// This function allows a member with the executor permission to execute a member removal
    /// transaction.
    ///
    /// # Parameters
    /// * `transaction_id` - The ID of the member removal transaction to execute.
    ///
    /// # Panics
    /// This function raises an error if the transaction with the given ID does not exist.
    /// This function raises an error if the transaction is not a member removal transaction.
    /// This function raises an error if the caller does not have the executor permission.
    /// This function raises an error if the transaction is already executed.
    /// This function raises an error if the transaction is not approved.
    /// This function raises an error if the contract is paused.
    fn execute_remove_member_transaction(ref self: TContractState, transaction_id: u256);
}
