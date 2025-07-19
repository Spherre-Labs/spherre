use spherre::types::MemberAddData;
use starknet::ContractAddress;

/// Interface for the MemberAddTransaction component.
/// This interface defines the entrypoints of the MemberAddTransaction component.
/// It includes methods for proposing, retrieving, and executing member addition transactions.

#[starknet::interface]
pub trait IMemberAddTransaction<TContractState> {
    /// Proposes a new member addition transaction.
    /// This function allows a member with the proposer permission to propose adding a new member
    /// to the account.
    ///
    /// # Parameters
    /// * `member` - The contract address of the member to be added.
    /// * `permissions` - The permissions to be granted to the new member as a permission mask.
    ///     Refer to the `PermissionEnum` enum for details on the permission mask.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the proposer permission.
    /// This function raises an error if the member address is already a member of the account.
    /// This function raises an error if the member address is the zero address.
    /// This function raises an error if the permissions mask is invalid
    ///
    /// # Returns
    /// * `u256` The ID of the proposed member addition transaction.
    fn propose_member_add_transaction(
        ref self: TContractState, member: ContractAddress, permissions: u8,
    ) -> u256;
    /// Retrieves a member addition transaction by its ID.
    /// This function allows retrieval of a specific member addition transaction
    /// by its unique identifier.
    ///
    /// # Parameters
    /// * `transaction_id` - The ID of the member addition transaction to retrieve.
    ///
    /// # Panics
    /// This function raises an error if the transaction with the given ID does not exist.
    /// This function raises an error if the transaction is not a member addition transaction.
    ///
    /// # Returns
    /// * `MemberAddData` The details of the member addition transaction.
    fn get_member_add_transaction(self: @TContractState, transaction_id: u256) -> MemberAddData;
    /// Retrieves all member addition transactions.
    /// This function returns a list of all member addition transactions that have been created.
    ///
    /// # Returns
    /// * `Array<MemberAddData>` An array of all member addition transactions.
    fn member_add_transaction_list(self: @TContractState) -> Array<MemberAddData>;
    /// Executes a member addition transaction.
    /// This function allows a member with the executor permission to execute a member addition
    /// transaction.
    ///
    /// # Parameters
    /// * `transaction_id` - The ID of the member addition transaction to execute.
    ///
    /// # Panics
    /// This function raises an error if the transaction with the given ID does not exist.
    /// This function raises an error if the transaction is not a member addition transaction.
    /// This function raises an error if the caller does not have the executor permission.
    /// This function raises an error if the transaction is already executed.
    /// This function raises an error if the transaction is not approved.
    /// This function raises an error if the contract is paused.
    fn execute_member_add_transaction(ref self: TContractState, transaction_id: u256);
}
