use spherre::types::ThresholdChangeData;

/// Interface for the ChangeThresholdTransaction component
/// This interface defines the entrypoints for managing threshold change transactions.
/// This includes proposing, retrieving, and executing threshold change transactions.

#[starknet::interface]
pub trait IChangeThresholdTransaction<TContractState> {
    /// Proposes a new threshold change transaction
    /// This function allows a member with the proposer permission to
    /// propose a change in the threshold for member actions.
    ///
    /// # Parameters
    /// * `new_threshold` - The new threshold value to be set
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the proposer permission.
    /// This function also raises an error if the new threshold is not valid
    /// (e.g., greater than the total number of members or 0).
    /// This function raises an error if the new threshold is equal to the current threshold.
    ///
    /// # Returns
    /// * `u256` The ID of the proposed threshold change transaction
    fn propose_threshold_change_transaction(ref self: TContractState, new_threshold: u64) -> u256;
    /// Retrieves a threshold change transaction by its ID
    /// This function allows retrieval of a specific threshold change transaction
    /// by its unique identifier.
    ///
    /// # Parameters
    /// * `id` - The id of the threshold change transaction
    ///
    /// # Panics
    /// This function raises an error if the transaction with the given ID does not exist.
    /// This funciton raises an error if the transaction is not a threshold change transaction.
    ///
    /// # Returns
    /// * `ThresholdChangeData` The details of the threshold change transaction
    fn get_threshold_change_transaction(self: @TContractState, id: u256) -> ThresholdChangeData;
    /// Retrieves all threshold change transactions
    /// This function returns a list of all threshold change transactions that have been created.
    ///
    /// # Returns
    /// * `Array<ThresholdChangeData>` An array of all threshold change transactions
    fn get_all_threshold_change_transactions(self: @TContractState) -> Array<ThresholdChangeData>;
    /// Executes a threshold change transaction
    /// This function allows a member with the executor permission to execute a threshold change
    /// transaction.
    ///
    /// # Parameters
    /// * `id` - The ID of the threshold change transaction to execute
    ///
    /// # Panics
    /// This function raises an error if the transaction with the given ID does not exist.
    /// This function raises an error if the transaction is not a threshold change transaction.
    /// This function raises an error if the caller does not have the executor permission.
    /// This function raises an error if the transaction is already executed.
    /// This function raises an error if the transaction is not approved.
    /// This function raises an error if the contract is paused.
    fn execute_threshold_change_transaction(ref self: TContractState, id: u256);
}
