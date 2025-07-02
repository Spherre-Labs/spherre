use spherre::types::{
    TransactionType, Transaction, NFTTransactionData, TransactionStatus, TokenTransactionData,
    ThresholdChangeData, MemberRemoveData, MemberAddData, EditPermissionTransaction,
    SmartTokenLockTransaction, MemberDetails
};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockContract<TContractState> {
    fn create_transaction_pub(ref self: TContractState, tx_type: TransactionType) -> u256;
    fn approve_transaction_pub(ref self: TContractState, tx_id: u256, caller: ContractAddress);
    fn reject_transaction_pub(ref self: TContractState, tx_id: u256, caller: ContractAddress);
    fn update_transaction_status(ref self: TContractState, tx_id: u256, status: TransactionStatus);
    fn add_member_pub(ref self: TContractState, member: ContractAddress);
    fn is_member_pub(self: @TContractState, member: ContractAddress) -> bool;
    fn has_permission_pub(
        self: @TContractState, member: ContractAddress, permission: felt252
    ) -> bool;
    fn assign_proposer_permission_pub(ref self: TContractState, member: ContractAddress);
    fn assign_voter_permission_pub(ref self: TContractState, member: ContractAddress);
    fn get_transaction_pub(self: @TContractState, id: u256) -> Transaction;
    fn set_threshold_pub(ref self: TContractState, val: u64);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn propose_token_transaction_pub(
        ref self: TContractState, token: ContractAddress, amount: u256, recipient: ContractAddress
    ) -> u256;
    fn execute_token_transaction_pub(ref self: TContractState, id: u256);
    fn get_token_transaction_pub(ref self: TContractState, id: u256) -> TokenTransactionData;
    fn execute_transaction_pub(ref self: TContractState, tx_id: u256, caller: ContractAddress);
    fn propose_smart_token_lock_transaction_pub(
        ref self: TContractState, token: ContractAddress, amount: u256, duration: u64
    ) -> u256;
    fn get_smart_token_lock_transaction_pub(
        self: @TContractState, transaction_id: u256
    ) -> SmartTokenLockTransaction;
    fn smart_token_lock_transaction_list_pub(
        self: @TContractState
    ) -> Array<SmartTokenLockTransaction>;
    fn assign_executor_permission_pub(ref self: TContractState, member: ContractAddress);
    fn propose_nft_transaction_pub(
        ref self: TContractState,
        nft_contract: ContractAddress,
        token_id: u256,
        recipient: ContractAddress
    ) -> u256;
    fn get_nft_transaction_pub(ref self: TContractState, id: u256) -> NFTTransactionData;
    fn nft_transaction_list_pub(ref self: TContractState) -> Array<NFTTransactionData>;
    fn propose_threshold_change_transaction_pub(
        ref self: TContractState, new_threshold: u64
    ) -> u256;
    fn get_threshold_change_transaction_pub(self: @TContractState, id: u256) -> ThresholdChangeData;
    fn get_all_threshold_change_transactions_pub(
        self: @TContractState
    ) -> Array<ThresholdChangeData>;
    fn propose_remove_member_transaction_pub(
        ref self: TContractState, member_address: ContractAddress
    ) -> u256;
    fn get_member_removal_transaction_pub(self: @TContractState, id: u256) -> MemberRemoveData;
    fn member_removal_transaction_list_pub(self: @TContractState) -> Array<MemberRemoveData>;
    fn propose_member_add_transaction_pub(
        ref self: TContractState, member: ContractAddress, permissions: u8
    ) -> u256;
    fn get_member_add_transaction_pub(self: @TContractState, transaction_id: u256) -> MemberAddData;
    fn member_add_transaction_list_pub(self: @TContractState) -> Array<MemberAddData>;
    fn execute_threshold_change_transaction_pub(ref self: TContractState, transaction_id: u256);
    fn get_threshold_pub(self: @TContractState) -> (u64, u64);
    fn execute_remove_member_transaction_pub(ref self: TContractState, transaction_id: u256);
    fn execute_member_add_transaction_pub(ref self: TContractState, transaction_id: u256);
    fn execute_nft_transaction_pub(ref self: TContractState, id: u256);
    fn propose_edit_permission_transaction_pub(
        ref self: TContractState, member: ContractAddress, new_permissions: u8
    ) -> u256;
    fn get_edit_permission_transaction_pub(
        self: @TContractState, transaction_id: u256
    ) -> EditPermissionTransaction;
    fn execute_edit_permission_transaction_pub(ref self: TContractState, transaction_id: u256);
    fn get_member_full_details_pub(self: @TContractState, member: ContractAddress) -> MemberDetails;
}


#[starknet::contract]
pub mod MockContract {
    // use AccountData::InternalTrait;
    use openzeppelin_security::pausable::PausableComponent;
    use spherre::account_data::AccountData;
    use spherre::actions::change_threshold_transaction::ChangeThresholdTransaction;
    use spherre::actions::member_add_transaction::MemberAddTransaction;
    use spherre::actions::member_permission_tx::MemberPermissionTransaction;
    use spherre::actions::member_remove_transaction::MemberRemoveTransaction;
    use spherre::actions::nft_transaction::NFTTransaction;
    use spherre::actions::smart_token_lock_transaction::SmartTokenLockTransactionComponent;
    use spherre::actions::token_transaction::TokenTransaction;
    use spherre::components::permission_control::{PermissionControl};
    use spherre::components::treasury_handler::{TreasuryHandler};
    use spherre::interfaces::itoken_tx::ITokenTransaction;
    use spherre::types::{
        Transaction, TransactionType, TransactionStatus, TokenTransactionData, NFTTransactionData,
        ThresholdChangeData, MemberRemoveData, MemberAddData, SmartTokenLockTransaction, 
        MemberDetails
    };
    use spherre::types::{EditPermissionTransaction};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess,};

    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: AccountData, storage: account_data, event: AccountDataEvent);
    component!(path: PermissionControl, storage: permission_control, event: PermissionControlEvent);
    component!(path: TokenTransaction, storage: token_transaction, event: TokenTransactionEvent);
    component!(
        path: SmartTokenLockTransactionComponent,
        storage: smart_token_lock_transaction,
        event: SmartTokenLockTransactionEvent
    );
    component!(path: TreasuryHandler, storage: treasury_handler, event: TreasuryHandlerEvent);
    component!(path: NFTTransaction, storage: nft_transaction, event: NFTTransactionEvent);
    component!(
        path: ChangeThresholdTransaction, storage: change_threshold, event: ChangeThresholdEvent
    );
    component!(path: MemberRemoveTransaction, storage: member_remove, event: MemberRemoveEvent);
    component!(path: MemberAddTransaction, storage: member_add, event: MemberAddEvent);
    component!(
        path: MemberPermissionTransaction, storage: member_permission, event: MemberPermissionEvent
    );

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

    #[abi(embed_v0)]
    pub impl TreasuryHandlerImpl = TreasuryHandler::TreasuryHandler<ContractState>;

    #[abi(embed_v0)]
    pub impl SmartTokenLockTransactionImpl =
        SmartTokenLockTransactionComponent::SmartTokenLockTransactionComponent<ContractState>;

    #[abi(embed_v0)]
    pub impl NFTTransactionImpl = NFTTransaction::NFTTransaction<ContractState>;

    #[abi(embed_v0)]
    pub impl ChangeThresholdTransactionImpl =
        ChangeThresholdTransaction::ChangeThresholdTransaction<ContractState>;

    #[abi(embed_v0)]
    pub impl MemberRemovalTransactionImpl =
        MemberRemoveTransaction::MemberRemoveTransaction<ContractState>;

    #[abi(embed_v0)]
    pub impl MemberAddTransactionImpl =
        MemberAddTransaction::MemberAddTransaction<ContractState>;

    #[abi(embed_v0)]
    pub impl MemberPermissionTransactionImpl =
        MemberPermissionTransaction::MemberPermissionTransaction<ContractState>;

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
        #[substorage(v0)]
        pub smart_token_lock_transaction: SmartTokenLockTransactionComponent::Storage,
        #[substorage(v0)]
        pub treasury_handler: TreasuryHandler::Storage,
        #[substorage(v0)]
        pub nft_transaction: NFTTransaction::Storage,
        #[substorage(v0)]
        pub change_threshold: ChangeThresholdTransaction::Storage,
        #[substorage(v0)]
        pub member_remove: MemberRemoveTransaction::Storage,
        #[substorage(v0)]
        pub member_add: MemberAddTransaction::Storage,
        #[substorage(v0)]
        pub member_permission: MemberPermissionTransaction::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AccountDataEvent: AccountData::Event,
        #[flat]
        PermissionControlEvent: PermissionControl::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        TokenTransactionEvent: TokenTransaction::Event,
        #[flat]
        SmartTokenLockTransactionEvent: SmartTokenLockTransactionComponent::Event,
        #[flat]
        TreasuryHandlerEvent: TreasuryHandler::Event,
        #[flat]
        NFTTransactionEvent: NFTTransaction::Event,
        #[flat]
        ChangeThresholdEvent: ChangeThresholdTransaction::Event,
        #[flat]
        MemberRemoveEvent: MemberRemoveTransaction::Event,
        #[flat]
        MemberAddEvent: MemberAddTransaction::Event,
        #[flat]
        MemberPermissionEvent: MemberPermissionTransaction::Event,
    }

    #[abi(embed_v0)]
    pub impl MockContractImpl of super::IMockContract<ContractState> {
        fn create_transaction_pub(ref self: ContractState, tx_type: TransactionType) -> u256 {
            self.account_data.create_transaction(tx_type)
        }
        fn approve_transaction_pub(ref self: ContractState, tx_id: u256, caller: ContractAddress) {
            // The caller address should be set in the test before calling this function
            self.account_data.approve_transaction(tx_id)
        }
        fn reject_transaction_pub(ref self: ContractState, tx_id: u256, caller: ContractAddress) {
            // The caller address should be set in the test before calling this function
            self.account_data.reject_transaction(tx_id)
        }
        fn update_transaction_status(
            ref self: ContractState, tx_id: u256, status: TransactionStatus
        ) {
            self.account_data._update_transaction_status(tx_id, status)
        }
        fn add_member_pub(ref self: ContractState, member: ContractAddress) {
            self.account_data._add_member(member);
        }
        fn is_member_pub(self: @ContractState, member: ContractAddress) -> bool {
            self.account_data.is_member(member)
        }
        fn has_permission_pub(
            self: @ContractState, member: ContractAddress, permission: felt252
        ) -> bool {
            self.permission_control.has_permission(member, permission)
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
        fn execute_token_transaction_pub(ref self: ContractState, id: u256) {
            self.token_transaction.execute_token_transaction(id)
        }
        fn propose_smart_token_lock_transaction_pub(
            ref self: ContractState, token: ContractAddress, amount: u256, duration: u64
        ) -> u256 {
            self
                .smart_token_lock_transaction
                .propose_smart_token_lock_transaction(token, amount, duration)
        }
        fn get_smart_token_lock_transaction_pub(
            self: @ContractState, transaction_id: u256
        ) -> SmartTokenLockTransaction {
            self.smart_token_lock_transaction.get_smart_token_lock_transaction(transaction_id)
        }
        fn smart_token_lock_transaction_list_pub(
            self: @ContractState
        ) -> Array<SmartTokenLockTransaction> {
            self.smart_token_lock_transaction.smart_token_lock_transaction_list()
        }
        fn execute_transaction_pub(ref self: ContractState, tx_id: u256, caller: ContractAddress) {
            self.account_data.execute_transaction(tx_id, caller)
        }

        fn assign_executor_permission_pub(ref self: ContractState, member: ContractAddress) {
            self.permission_control.assign_executor_permission(member);
        }

        fn propose_nft_transaction_pub(
            ref self: ContractState,
            nft_contract: ContractAddress,
            token_id: u256,
            recipient: ContractAddress
        ) -> u256 {
            self.nft_transaction.propose_nft_transaction(nft_contract, token_id, recipient)
        }
        fn get_nft_transaction_pub(ref self: ContractState, id: u256) -> NFTTransactionData {
            self.nft_transaction.get_nft_transaction(id)
        }

        fn nft_transaction_list_pub(ref self: ContractState) -> Array<NFTTransactionData> {
            let transaction_list = self.nft_transaction.nft_transaction_list();
            transaction_list
        }

        fn propose_threshold_change_transaction_pub(
            ref self: ContractState, new_threshold: u64
        ) -> u256 {
            self.change_threshold.propose_threshold_change_transaction(new_threshold)
        }

        fn get_threshold_change_transaction_pub(
            self: @ContractState, id: u256
        ) -> ThresholdChangeData {
            self.change_threshold.get_threshold_change_transaction(id)
        }

        fn get_all_threshold_change_transactions_pub(
            self: @ContractState
        ) -> Array<ThresholdChangeData> {
            let threshold_change_txs = self
                .change_threshold
                .get_all_threshold_change_transactions();
            threshold_change_txs
        }

        fn propose_remove_member_transaction_pub(
            ref self: ContractState, member_address: ContractAddress
        ) -> u256 {
            self.member_remove.propose_remove_member_transaction(member_address)
        }

        fn get_member_removal_transaction_pub(self: @ContractState, id: u256) -> MemberRemoveData {
            self.member_remove.get_member_removal_transaction(id)
        }

        fn member_removal_transaction_list_pub(self: @ContractState) -> Array<MemberRemoveData> {
            self.member_remove.member_removal_transaction_list()
        }
        fn propose_member_add_transaction_pub(
            ref self: ContractState, member: ContractAddress, permissions: u8
        ) -> u256 {
            self.member_add.propose_member_add_transaction(member, permissions)
        }
        fn get_member_add_transaction_pub(
            self: @ContractState, transaction_id: u256
        ) -> MemberAddData {
            self.member_add.get_member_add_transaction(transaction_id)
        }
        fn member_add_transaction_list_pub(self: @ContractState) -> Array<MemberAddData> {
            self.member_add.member_add_transaction_list()
        }
        fn execute_threshold_change_transaction_pub(ref self: ContractState, transaction_id: u256) {
            self.change_threshold.execute_threshold_change_transaction(transaction_id);
        }
        fn get_threshold_pub(self: @ContractState) -> (u64, u64) {
            self.account_data.get_threshold()
        }
        fn execute_remove_member_transaction_pub(ref self: ContractState, transaction_id: u256) {
            self.member_remove.execute_remove_member_transaction(transaction_id);
        }
        fn execute_member_add_transaction_pub(ref self: ContractState, transaction_id: u256) {
            self.member_add.execute_member_add_transaction(transaction_id);
        }
        fn execute_nft_transaction_pub(ref self: ContractState, id: u256) {
            self.nft_transaction.execute_nft_transaction(id);
        }
        fn propose_edit_permission_transaction_pub(
            ref self: ContractState, member: ContractAddress, new_permissions: u8
        ) -> u256 {
            self.member_permission.propose_edit_permission_transaction(member, new_permissions)
        }
        fn get_edit_permission_transaction_pub(
            self: @ContractState, transaction_id: u256
        ) -> EditPermissionTransaction {
            self.member_permission.get_edit_permission_transaction(transaction_id)
        }
        fn execute_edit_permission_transaction_pub(ref self: ContractState, transaction_id: u256) {
            self.member_permission.execute_edit_permission_transaction(transaction_id);
        }
        fn get_member_full_details_pub(self: @ContractState, member: ContractAddress) -> MemberDetails {
            self.account_data.get_member_full_details(member)
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
        fn get_member_full_details(self: @ContractState, member: ContractAddress) -> MemberDetails {
            self.account_data.get_member_full_details(member)
        }
    }
}
