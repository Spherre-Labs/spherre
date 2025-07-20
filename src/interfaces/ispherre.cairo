use spherre::types::FeesType;
use starknet::{ClassHash, ContractAddress};

/// Interface for the Spherre contract
/// This interface defines the entrypoints of the Spherre contract.
/// It includes methods for managing roles, deploying accounts,
/// handling account class hashes and much more.

#[starknet::interface]
pub trait ISpherre<TContractState> {
    /// Grants the superadmin role to a specified account.
    /// This function allows a superadmin to grant the superadmin role to another account.
    ///
    /// # Parameters
    /// * `account` - The contract address of the account to grant the superadmin role to.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the superadmin role.
    fn grant_superadmin_role(ref self: TContractState, account: ContractAddress);
    /// Grants the staff role to a specified account.
    /// This function allows a superadmin to grant the staff role to another account.
    ///
    /// # Parameters
    /// * `account` - The contract address of the account to grant the staff role to.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the superadmin role.
    fn grant_staff_role(ref self: TContractState, account: ContractAddress);
    /// Revokes the superadmin role from a specified account.
    /// This function allows a superadmin to revoke the superadmin role from another account.
    ///
    /// # Parameters
    /// * `account` - The contract address of the account to revoke the superadmin role from.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the superadmin role.
    fn revoke_superadmin_role(ref self: TContractState, account: ContractAddress);
    /// Revokes the staff role from a specified account.
    /// This function allows a superadmin to revoke the staff role from another account.
    ///
    /// # Parameters
    /// * `account` - The contract address of the account to revoke the staff role from.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the superadmin role.
    fn revoke_staff_role(ref self: TContractState, account: ContractAddress);
    /// Checks if an account has the staff role.
    ///
    /// # Parameters
    /// * `account` - The contract address of the account to check.
    ///
    /// # Returns
    /// * `bool` - Returns true if the account has the staff role, false otherwise.
    fn has_staff_role(self: @TContractState, account: ContractAddress) -> bool;
    /// Checks if an account has the superadmin role.
    ///
    /// # Parameters
    /// * `account` - The contract address of the account to check.
    ///
    /// # Returns
    /// * `bool` - Returns true if the account has the superadmin role, false otherwise.
    fn has_superadmin_role(self: @TContractState, account: ContractAddress) -> bool;
    /// Pauses the Spherre contract.
    /// This function allows a superadmin to pause the contract, preventing any further actions
    /// until it is unpaused.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the superadmin role.
    fn pause(ref self: TContractState);
    /// Unpauses the Spherre contract.
    /// This function allows a superadmin to unpause the contract, resuming normal operations.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the superadmin role.
    ///
    fn unpause(ref self: TContractState);
    /// Deploys a new account with the specified parameters.
    /// This function allows an account to deploy a new SpherreAccount with the given owner,
    /// name, description, members, and threshold.
    ///
    /// # Parameters
    /// * `owner` - The contract address of the account owner.
    /// * `name` - The name of the account as a byte array.
    /// * `description` - The description of the account as a byte array.
    /// * `members` - An array of contract addresses representing the members of the account.
    /// * `threshold` - The threshold for member actions, represented as a u64 value.
    ///
    /// # Returns
    /// * `ContractAddress` - The address of the newly deployed account.
    fn deploy_account(
        ref self: TContractState,
        owner: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        members: Array<ContractAddress>,
        threshold: u64,
    ) -> ContractAddress;
    /// Checks if an account is deployed.
    /// This function checks if a given account address corresponds to a deployed SpherreAccount.
    ///
    /// # Parameters
    /// * `account` - The contract address of the account to check.
    ///
    /// # Returns
    /// * `bool` - Returns true if the account is deployed, false otherwise.
    fn is_deployed_account(self: @TContractState, account: ContractAddress) -> bool;
    /// Updates the class hash of the SpherreAccount contract.
    /// This function allows a superadmin to update the class hash of the SpherreAccount contract,
    /// which is used for deploying new accounts.
    ///
    /// # Parameters
    /// * `new_class_hash` - The new class hash to set for the SpherreAccount contract.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the superadmin role.
    fn update_account_class_hash(ref self: TContractState, new_class_hash: ClassHash);
    /// Retrieves the current class hash of the SpherreAccount contract.
    /// This function returns the class hash that is currently used for deploying new accounts.
    ///
    /// # Returns
    /// * `ClassHash` - The class hash of the SpherreAccount contract.
    fn get_account_class_hash(self: @TContractState) -> ClassHash;
    /// Upgrades the Spherre contract.
    /// This function allows a superadmin to upgrade the Spherre contract.
    ///
    /// # Parameters
    /// * `new_class_hash` - The new class hash to set for the new Spherre contract.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the superadmin role.
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    /// Updates the fee amount for a given fee type.
    /// This function allows a staff member to update the fee amount for a given fee type.
    ///
    /// # Parameters
    /// * `fee_type` - The type of fee to update.
    /// * `amount` - The new fee amount.
    fn update_fee(ref self: TContractState, fee_type: FeesType, amount: u256);
    /// Updates the fee token address.
    /// This function allows a superadmin to update the fee token address.
    ///
    /// # Parameters
    /// * `token_address` - The new fee token address.
    ///
    /// # Panics
    /// This function raises an error if the caller does not have the superadmin role.
    fn update_fee_token(ref self: TContractState, token_address: ContractAddress);
    /// Gets the fee amount for a given fee type.
    ///
    /// # Parameters
    /// * `fee_type` - The type of fee to query.
    /// *  `account` - The account that is being charged
    ///
    /// # Returns
    /// * `u256` - The fee amount, or 0 if the fee is not enabled.
    fn get_fee(self: @TContractState, fee_type: FeesType, account: ContractAddress) -> u256;
    /// Gets the fee token for a fee payment.
    ///
    /// # Returns
    /// * `ContractAddress` - The fee token
    fn get_fee_token(self: @TContractState) -> ContractAddress;
    /// Checks if a fee type is enabled.
    ///
    /// # Parameters
    /// * `fee_type` - The type of fee to check.
    ///
    /// # Returns
    /// * `bool` - Returns true if the fee type is enabled, false otherwise.
    fn is_fee_enabled(self: @TContractState, fee_type: FeesType) -> bool;
    /// Update the fee collection statistics of an account
    ///
    /// # Parameters
    /// * `fee_type` - The type of fee
    /// * `amount` - The amount of fee to add (record)
    ///
    fn update_fee_collection_statistics(ref self: TContractState, fee_type: FeesType, amount: u256);
    /// Get the fee collected from an account operations
    ///
    /// # Parameters
    /// * `fee_type` - The type of fee
    /// * `account` - The account
    ///
    fn get_fees_collected(
        self: @TContractState, fee_type: FeesType, account: ContractAddress,
    ) -> u256;
    /// Whitelist an account.
    ///
    /// # Parameters
    /// * `account` - The account to whitelist.
    fn whitelist_account(ref self: TContractState, account: ContractAddress);
    /// Whitelist a user.
    ///
    /// # Parameters
    /// * `user` - The user to whitelist.
    fn whitelist_user(ref self: TContractState, user: ContractAddress);
    /// Remove an account from whitelist.
    ///
    /// # Parameters
    /// * `account` - The account to remove from whitelist.
    fn remove_account_from_whitelist(ref self: TContractState, account: ContractAddress);
    /// Remove a user from whitelist.
    ///
    /// # Parameters
    /// * `user` - The user to remove from whitelist.
    fn remove_user_from_whitelist(ref self: TContractState, user: ContractAddress);
    /// Check if an account is whitelisted.
    ///
    /// # Parameters
    /// * `account` - The account to check.
    ///
    /// # Returns
    /// * `bool` - Returns true if account is whitelisted, false otherwise.
    fn is_whitelisted_account(self: @TContractState, account: ContractAddress) -> bool;
    /// Check if a user is whitelisted.
    ///
    /// # Parameters
    /// * `user` - The user to check.
    ///
    /// # Returns
    /// * `bool` - Returns true if user is whitelisted, false otherwise.
    fn is_whitelisted_user(self: @TContractState, user: ContractAddress) -> bool;
    /// Get the total number of whitelisted accounts.
    ///
    /// # Returns
    /// * `u256` - The total number of whitelisted accounts.
    fn get_whitelisted_accounts_count(self: @TContractState) -> u256;
    /// Get the total number of whitelisted users.
    ///
    /// # Returns
    /// * `u256` - The total number of whitelisted users.
    fn get_whitelisted_users_count(self: @TContractState) -> u256;
    /// Get the timestamp when an address was whitelisted.
    ///
    /// # Parameters
    /// * `address` - The address to check
    /// * `is_account` - True for account whitelist, false for user whitelist
    ///
    /// # Returns
    fn get_whitelist_time(self: @TContractState, address: ContractAddress, is_account: bool) -> u64;
    /// Sets the deployment fee percentage.
    /// This function allows a staff member or superadmin to set the percentage fee
    /// charged during account deployment. This value is used to calculate the amount
    /// distibuted to `Spherre` contract and newly deployed account.
    ///
    /// # Parameters
    /// * `percentage` - The new deployment fee percentage to set (e.g., 5 for 5%).
    fn set_deployment_fee_percentage(ref self: TContractState, percentage: u64);
    /// Retrieves the current deployment fee percentage..
    ///
    /// # Returns
    /// * `u64` - The currently set deployment fee percentage.
    fn get_deployment_fee_percentage(self: @TContractState) -> u64;
}
