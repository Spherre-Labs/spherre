//! This module defines the Spherre Account contract, which is a multi-signature account
//! with various components for managing permissions, transactions, and account data.
//!
//! The comment documentation for public entrypoints can be found in the `IAccount` interface.
#[starknet::contract]
pub mod SpherreAccount {
    use AccountData::InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721ReceiverComponent;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_security::pausable::PausableComponent;
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use spherre::{
        account_data::AccountData,
        actions::{
            change_threshold_transaction::ChangeThresholdTransaction,
            member_add_transaction::MemberAddTransaction,
            member_permission_tx::MemberPermissionTransaction,
            member_remove_transaction::MemberRemoveTransaction, nft_transaction::NFTTransaction,
            smart_token_lock_transaction::SmartTokenLockTransactionComponent,
            token_transaction::TokenTransaction,
        },
        components::{permission_control::PermissionControl, treasury_handler::TreasuryHandler},
        interfaces::iaccount::IAccount, types::{AccountDetails, TransactionStatus, TransactionType},
        {errors::Errors},
    };
    use starknet::{
        {ClassHash, ContractAddress, contract_address_const, get_caller_address},
        {storage::{StorableStoragePointerReadAccess, StoragePointerWriteAccess}},
    };

    component!(path: AccountData, storage: account_data, event: AccountDataEvent);
    component!(path: PermissionControl, storage: permission_control, event: PermissionControlEvent);
    component!(path: TreasuryHandler, storage: treasury_handler, event: TreasuryHandlerEvent);
    component!(
        path: ChangeThresholdTransaction,
        storage: change_threshold_transaction,
        event: ChangeThresholdEvent,
    );
    component!(
        path: MemberAddTransaction,
        storage: member_add_transaction,
        event: MemberAddTransactionEvent,
    );
    component!(
        path: MemberRemoveTransaction,
        storage: member_remove_transaction,
        event: MemberRemoveTransactionEvent,
    );
    component!(
        path: MemberPermissionTransaction,
        storage: member_permission_transaction,
        event: MemberPermissionTransactionEvent,
    );
    component!(
        path: SmartTokenLockTransactionComponent,
        storage: smart_token_lock_transaction,
        event: SmartTokenLockTransactionEvent,
    );
    component!(path: NFTTransaction, storage: nft_transaction, event: NFTTransactionEvent);
    component!(path: TokenTransaction, storage: token_transaction, event: TokenTransactionEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: ERC721ReceiverComponent, storage: erc721_receiver, event: ERC721ReceiverEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // AccountData component implementation
    #[abi(embed_v0)]
    impl AccountDataImpl = AccountData::AccountData<ContractState>;
    impl AccountDataInternalImpl = AccountData::InternalImpl<ContractState>;

    // PermissionControl component implementation
    #[abi(embed_v0)]
    impl PermissionControlImpl =
        PermissionControl::PermissionControl<ContractState>;
    impl PermissionControlInternalImpl = PermissionControl::InternalImpl<ContractState>;

    // TreasuryHandler component implementation
    #[abi(embed_v0)]
    impl TreasuryHandlerImpl = TreasuryHandler::TreasuryHandler<ContractState>;
    impl TreasuryHandlerInternalImpl = TreasuryHandler::InternalImpl<ContractState>;

    // Pausable component implementation
    #[abi(embed_v0)]
    pub impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    pub impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Upgradeable component implementation
    pub impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // Implement SRC5 mixin
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    // Implement ERC721Receiver mixin
    #[abi(embed_v0)]
    impl ERC721ReceiverMixinImpl =
        ERC721ReceiverComponent::ERC721ReceiverMixinImpl<ContractState>;
    impl ERC721ReceiverInternalImpl = ERC721ReceiverComponent::InternalImpl<ContractState>;

    // Integrate the actions components to the contract

    // ChangeThresholdTransaction component implementation
    #[abi(embed_v0)]
    impl ChangeThresholdTransactionImpl =
        ChangeThresholdTransaction::ChangeThresholdTransaction<ContractState>;

    // MemberAddTransaction component implementation
    #[abi(embed_v0)]
    impl MemberAddTransactionImpl =
        MemberAddTransaction::MemberAddTransaction<ContractState>;

    // MemberRemoveTransaction component implementation
    #[abi(embed_v0)]
    impl MemberRemoveTransactionImpl =
        MemberRemoveTransaction::MemberRemoveTransaction<ContractState>;
    impl MemberRemoveInternalImpl = MemberRemoveTransaction::PrivateImpl<ContractState>;

    // MemberPermissionTransaction component implementation
    #[abi(embed_v0)]
    impl MemberPermissionTransactionImpl =
        MemberPermissionTransaction::MemberPermissionTransaction<ContractState>;

    // SmartTokenLockTransaction component implementation
    #[abi(embed_v0)]
    impl SmartTokenLockTransactionImpl =
        SmartTokenLockTransactionComponent::SmartTokenLockTransactionComponent<ContractState>;

    // NFTTransaction component implementation
    #[abi(embed_v0)]
    impl NFTTransactionImpl = NFTTransaction::NFTTransaction<ContractState>;

    // TokenTransaction component implementation
    #[abi(embed_v0)]
    impl TokenTransactionImpl = TokenTransaction::TokenTransaction<ContractState>;
    impl TokenTransactionInternalImpl = TokenTransaction::PrivateImpl<ContractState>;

    #[storage]
    struct Storage {
        pub deployer: ContractAddress,
        pub contract_address: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        #[substorage(v0)]
        account_data: AccountData::Storage,
        #[substorage(v0)]
        permission_control: PermissionControl::Storage,
        #[substorage(v0)]
        treasury_handler: TreasuryHandler::Storage,
        #[substorage(v0)]
        change_threshold_transaction: ChangeThresholdTransaction::Storage,
        #[substorage(v0)]
        member_add_transaction: MemberAddTransaction::Storage,
        #[substorage(v0)]
        member_remove_transaction: MemberRemoveTransaction::Storage,
        #[substorage(v0)]
        member_permission_transaction: MemberPermissionTransaction::Storage,
        #[substorage(v0)]
        smart_token_lock_transaction: SmartTokenLockTransactionComponent::Storage,
        #[substorage(v0)]
        nft_transaction: NFTTransaction::Storage,
        #[substorage(v0)]
        token_transaction: TokenTransaction::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        pub erc721_receiver: ERC721ReceiverComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AccountDataEvent: AccountData::Event,
        #[flat]
        PermissionControlEvent: PermissionControl::Event,
        #[flat]
        TreasuryHandlerEvent: TreasuryHandler::Event,
        #[flat]
        ChangeThresholdEvent: ChangeThresholdTransaction::Event,
        #[flat]
        MemberAddTransactionEvent: MemberAddTransaction::Event,
        #[flat]
        MemberRemoveTransactionEvent: MemberRemoveTransaction::Event,
        #[flat]
        MemberPermissionTransactionEvent: MemberPermissionTransaction::Event,
        #[flat]
        SmartTokenLockTransactionEvent: SmartTokenLockTransactionComponent::Event,
        #[flat]
        NFTTransactionEvent: NFTTransaction::Event,
        #[flat]
        TokenTransactionEvent: TokenTransaction::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        ERC721ReceiverEvent: ERC721ReceiverComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        deployer: ContractAddress,
        owner: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        members: Array<ContractAddress>,
        threshold: u64,
    ) {
        assert(deployer != contract_address_const::<0>(), Errors::ERR_DEPLOYER_ZERO);
        assert(owner != contract_address_const::<0>(), Errors::ERR_OWNER_ZERO);
        assert(members.len() > 0, Errors::NON_ZERO_MEMBER_LENGTH);
        assert(threshold > 0, Errors::NON_ZERO_THRESHOLD);
        assert((members.len()).into() >= threshold, Errors::ERR_INVALID_MEMBER_THRESHOLD);

        //TODO: add assertion check to check that owner is in members array.

        self.name.write(name);
        self.description.write(description);
        let len_member = members.len();
        for index in 0..len_member {
            let member = *members.at(index);
            self.account_data._add_member(member);
            self.permission_control.assign_all_permissions(member);
        };
        self.account_data.set_threshold(threshold);

        // Record deployer
        self.deployer.write(deployer);

        // Initialize Ownable component
        self.ownable.initializer(deployer);

        // Initialize ERC721Receiver
        self.erc721_receiver.initializer();
    }

    #[abi(embed_v0)]
    pub impl AccountImpl of IAccount<ContractState> {
        fn get_name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn get_description(self: @ContractState) -> ByteArray {
            self.description.read()
        }
        fn get_account_details(self: @ContractState) -> AccountDetails {
            AccountDetails { name: self.name.read(), description: self.description.read() }
        }
        fn get_deployer(self: @ContractState) -> ContractAddress {
            self.deployer.read()
        }

        fn pause(ref self: ContractState) {
            let caller = get_caller_address();
            let deployer = self.deployer.read();
            assert(caller == deployer, Errors::ERR_NOT_DEPLOYER);
            // The Pausable component automatically emits events when the respective functions are
            // called. These events are included in the PausableEvent variant.
            self.pausable.pause();
        }
        fn unpause(ref self: ContractState) {
            let caller = get_caller_address();
            let deployer = self.deployer.read();
            assert(caller == deployer, Errors::ERR_NOT_DEPLOYER);
            self.pausable.unpause();
        }
        fn execute_transaction(ref self: ContractState, transaction_id: u256) {
            let transaction = self.account_data.get_transaction(transaction_id);
            // Check if the transaction is executable
            assert(
                transaction.tx_status == TransactionStatus::APPROVED,
                Errors::ERR_TRANSACTION_NOT_EXECUTABLE,
            );

            match transaction.tx_type {
                // Handle ChangeThresholdTransaction
                TransactionType::THRESHOLD_CHANGE => {
                    self
                        .change_threshold_transaction
                        .execute_threshold_change_transaction(transaction_id);
                },
                // Handle MemberAddTransaction
                TransactionType::MEMBER_ADD => {
                    self.member_add_transaction.execute_member_add_transaction(transaction_id);
                },
                // Handle MemberRemoveTransaction
                TransactionType::MEMBER_REMOVE => {
                    self
                        .member_remove_transaction
                        .execute_remove_member_transaction(transaction_id);
                },
                // Handle MemberPermissionTransaction
                TransactionType::MEMBER_PERMISSION_EDIT => {
                    self
                        .member_permission_transaction
                        .execute_edit_permission_transaction(transaction_id);
                },
                // Handle NFTTransaction
                TransactionType::NFT_SEND => {
                    self.nft_transaction.execute_nft_transaction(transaction_id);
                },
                // Handle TokenTransaction
                TransactionType::TOKEN_SEND => {
                    self.token_transaction.execute_token_transaction(transaction_id);
                },
                TransactionType::SMART_TOKEN_LOCK => {
                    self
                        .smart_token_lock_transaction
                        .execute_smart_token_lock_transaction(transaction_id);
                },
                _ => {
                    // If the transaction type is not recognized, raise an error
                    panic(array![Errors::ERR_INVALID_TRANSACTION_TYPE]);
                },
            }
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the deployer
            self.ownable.assert_only_owner();

            // Replace the class hash, hence upgrading the contract
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
