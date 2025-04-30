use spherre::types::{TransactionType, Transaction, TransactionStatus, TokenTransactionData};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockContract<TContractState> {
    fn create_transaction_pub(ref self: TContractState, tx_type: TransactionType) -> u256;
    fn approve_transaction_pub(ref self: TContractState, tx_id: u256, caller: ContractAddress);
    fn reject_transaction_pub(ref self: TContractState, tx_id: u256, caller: ContractAddress);
    fn update_transaction_status(ref self: TContractState, tx_id: u256, status: TransactionStatus);
    fn add_member_pub(ref self: TContractState, member: ContractAddress);
    fn assign_proposer_permission_pub(ref self: TContractState, member: ContractAddress);
    fn assign_voter_permission_pub(ref self: TContractState, member: ContractAddress);
    fn get_transaction_pub(self: @TContractState, id: u256) -> Transaction;
    fn set_threshold_pub(ref self: TContractState, val: u64);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn propose_token_transaction_pub(
        ref self: TContractState, token: ContractAddress, amount: u256, recipient: ContractAddress
    ) -> u256;
    fn get_token_transaction_pub(ref self: TContractState, id: u256) -> TokenTransactionData;
    fn execute_transaction_pub(ref self: TContractState, tx_id: u256, caller: ContractAddress);
    fn assign_executor_permission_pub(ref self: TContractState, member: ContractAddress);
}


#[starknet::contract]
pub mod MockContract {
    // use AccountData::InternalTrait;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::account_data::AccountData;
    use spherre::actions::token_transaction::TokenTransaction;
    use spherre::components::permission_control::{PermissionControl};
    use spherre::interfaces::itoken_tx::ITokenTransaction;
    use spherre::types::{Transaction, TransactionType, TransactionStatus, TokenTransactionData};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess,};

    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: AccountData, storage: account_data, event: AccountDataEvent);
    component!(path: PermissionControl, storage: permission_control, event: PermissionControlEvent);
    component!(path: TokenTransaction, storage: token_transaction, event: TokenTransactionEvent);

    #[abi(embed_v0)]
    pub impl AccountDataImpl = AccountData::AccountData<ContractState>;
    pub impl AccountDataInternalImpl = AccountData::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    pub impl PermissionControlImpl =
        PermissionControl::PermissionControl<ContractState>;
    pub impl PermissionInternalImpl = PermissionControl::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    pub impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    pub impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    pub impl TokenTransactionImpl =
        TokenTransaction::TokenTransaction<ContractState>;


    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub account_data: AccountData::Storage,
        #[substorage(v0)]
        pub permission_control: PermissionControl::Storage,
        #[substorage(v0)]
        pub pausable: PausableComponent::Storage,
        #[substorage(v0)]
        pub token_transaction: TokenTransaction::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountDataEvent: AccountData::Event,
        #[flat]
        PermissionControlEvent: PermissionControl::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        TokenTransactionEvent: TokenTransaction::Event,
    }

    #[abi(embed_v0)]
    pub impl MockContractImpl of super::IMockContract<ContractState> {
        fn create_transaction_pub(ref self: ContractState, tx_type: TransactionType) -> u256 {
            self.account_data.create_transaction(tx_type)
        }
        fn approve_transaction_pub(ref self: ContractState, tx_id: u256, caller: ContractAddress) {
            self.account_data.approve_transaction(tx_id, caller)
        }
        fn reject_transaction_pub(ref self: ContractState, tx_id: u256, caller: ContractAddress) {
            self.account_data.reject_transaction(tx_id, caller)
        }
        fn update_transaction_status(
            ref self: ContractState, tx_id: u256, status: TransactionStatus
        ) {
            self.account_data._update_transaction_status(tx_id, status)
        }
        fn add_member_pub(ref self: ContractState, member: ContractAddress) {
            self.account_data._add_member(member);
        }
        fn assign_proposer_permission_pub(ref self: ContractState, member: ContractAddress) {
            self.permission_control.assign_proposer_permission(member);
        }
        fn assign_voter_permission_pub(ref self: ContractState, member: ContractAddress) {
            self.permission_control.assign_voter_permission(member);
        }
        fn get_transaction_pub(self: @ContractState, id: u256) -> Transaction {
            self.account_data.get_transaction(id)
        }
        fn get_token_transaction_pub(ref self: ContractState, id: u256) -> TokenTransactionData {
            self.token_transaction.get_token_transaction(id)
        }
        fn set_threshold_pub(ref self: ContractState, val: u64) {
            self.account_data.set_threshold(val);
        }
        fn pause(ref self: ContractState) {
            self.pausable.pause();
        }

        fn unpause(ref self: ContractState) {
            self.pausable.unpause();
        }

        fn propose_token_transaction_pub(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            recipient: ContractAddress
        ) -> u256 {
            self.token_transaction.propose_token_transaction(token, amount, recipient)
        }

        fn execute_transaction_pub(ref self: ContractState, tx_id: u256, caller: ContractAddress) {
            self.account_data.execute_transaction(tx_id, caller)
        }

        fn assign_executor_permission_pub(ref self: ContractState, member: ContractAddress) {
            self.permission_control.assign_executor_permission(member);
        }
    }

    #[generate_trait]
    pub impl PrivateImpl of PrivateTrait {
        fn is_member(self: @ContractState, member: ContractAddress) -> bool {
            self.account_data.is_member(member)
        }
        fn get_members(self: @ContractState) -> Array<ContractAddress> {
            let members = self.account_data.get_account_members();
            members
        }

        fn get_members_count(self: @ContractState) -> u64 {
            self.account_data.members_count.read()
        }
        fn set_threshold(ref self: ContractState, val: u64) {
            self.account_data.set_threshold(val);
        }
        fn get_threshold(self: @ContractState) -> (u64, u64) {
            self.account_data.get_threshold()
        }
        fn edit_member_count(ref self: ContractState, val: u64) {
            self.account_data.members_count.write(val);
        }

        // Expose the main contract's get_transaction function
        fn get_transaction(self: @ContractState, transaction_id: u256) -> Transaction {
            self.account_data.get_transaction(transaction_id)
        }

        fn add_member(ref self: ContractState, member: ContractAddress) {
            self.account_data._add_member(member);
        }
        fn assign_voter_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control.assign_voter_permission(member);
        }
        fn assign_proposer_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control.assign_proposer_permission(member);
        }
        fn assign_executor_permission(ref self: ContractState, member: ContractAddress) {
            self.permission_control.assign_executor_permission(member);
        }
        fn get_number_of_voters(self: @ContractState) -> u64 {
            self.account_data.get_number_of_voters()
        }
        fn get_number_of_proposers(self: @ContractState) -> u64 {
            self.account_data.get_number_of_proposers()
        }
        fn get_number_of_executors(self: @ContractState) -> u64 {
            self.account_data.get_number_of_executors()
        }
    }
}
