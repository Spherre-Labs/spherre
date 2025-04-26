// use spherre::errors::ThresholdError;
#[starknet::contract]
pub mod SpherreAccount {
    use core::traits::TryInto;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use spherre::account_data::AccountData;
    use spherre::actions::change_threshold_tx::ChangeThresholdTransaction;
    use spherre::actions::member_permission_tx::MemberPermissionTransaction;
    use spherre::actions::member_tx::MemberTransaction;
    use spherre::actions::nft_tx::NFTTransaction;
    use spherre::actions::token_tx::TokenTransaction;
    use spherre::errors::Errors;
    use spherre::types::AccountDetails;
    use starknet::storage::{StorableStoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ClassHash, ContractAddress, contract_address_const, get_caller_address};

    component!(path: AccountData, storage: account_data, event: AccountDataEvent);
    component!(
        path: ChangeThresholdTransaction,
        storage: change_threshold_transaction,
        event: ChangeThresholdEvent,
    );
    component!(path: MemberTransaction, storage: member_transaction, event: MemberTransactionEvent);
    component!(
        path: MemberPermissionTransaction,
        storage: member_permission_transaction,
        event: MemberPermissionTransactionEvent,
    );
    component!(path: NFTTransaction, storage: nft_transaction, event: NFTTransactionEvent);
    component!(path: TokenTransaction, storage: token_transaction, event: TokenTransactionEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[storage]
    struct Storage {
        deployer: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        #[substorage(v0)]
        account_data: AccountData::Storage,
        #[substorage(v0)]
        change_threshold_transaction: ChangeThresholdTransaction::Storage,
        #[substorage(v0)]
        member_transaction: MemberTransaction::Storage,
        #[substorage(v0)]
        member_permission_transaction: MemberPermissionTransaction::Storage,
        #[substorage(v0)]
        nft_transaction: NFTTransaction::Storage,
        #[substorage(v0)]
        token_transaction: TokenTransaction::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AccountDataEvent: AccountData::Event,
        #[flat]
        ChangeThresholdEvent: ChangeThresholdTransaction::Event,
        #[flat]
        MemberTransactionEvent: MemberTransaction::Event,
        #[flat]
        MemberPermissionTransactionEvent: MemberPermissionTransaction::Event,
        #[flat]
        NFTTransactionEvent: NFTTransaction::Event,
        #[flat]
        TokenTransactionEvent: TokenTransaction::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        AccountUpgraded: AccountUpgradedEvent,
    }

    #[derive(Drop, starknet::Event)]
    struct AccountUpgradedEvent {
        deployer: ContractAddress,
        new_class_hash: ClassHash,
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
        assert((members.len()).into() >= threshold, Errors::ERR_INVALID_MEMBER_THRESHOLD);
        self.name.write(name);
        self.description.write(description);
        self.deployer.write(deployer);
    }

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // External implementation of the IUpgradeable interface
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // Ensure only the deployer can upgrade the contract
            let caller = get_caller_address();
            let deployer = self.deployer.read();

            assert(deployer == caller, Errors::ERR_UNAUTHORIZED);

            // Ensure the new class hash is not zero
            let zero_class_hash: ClassHash = 0.try_into().unwrap();
            assert(new_class_hash != zero_class_hash, Errors::ERR_INVALID_CLASS_HASH);

            self.upgradeable.upgrade(new_class_hash);

            self
                .emit(
                    Event::AccountUpgraded(
                        AccountUpgradedEvent { deployer: deployer, new_class_hash: new_class_hash },
                    ),
                );
        }
    }

    #[generate_trait]
    pub impl SpherreAccountImpl of ISpherreAccount {
        fn get_name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn get_description(self: @ContractState) -> ByteArray {
            self.description.read()
        }

        fn get_account_details(self: @ContractState) -> AccountDetails {
            AccountDetails { name: self.name.read(), description: self.description.read() }
        }
    }
}
