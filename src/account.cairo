
#[starknet::contract]
pub mod SpherreAccount {
    use spherre::{
        account_data::AccountData,
        actions::{
            change_threshold_tx::ChangeThresholdTransaction,
            member_permission_tx::MemberPermissionTransaction, member_tx::MemberTransaction,
            nft_tx::NFTTransaction, token_tx::TokenTransaction
        }
    };
    use starknet::ContractAddress;

    component!(path: AccountData, storage: account_data, event: AccountDataEvent);
    component!(
        path: ChangeThresholdTransaction,
        storage: change_threshold_transaction,
        event: ChangeThresholdEvent
    );
    component!(path: MemberTransaction, storage: member_transaction, event: MemberTransactionEvent);
    component!(
        path: MemberPermissionTransaction,
        storage: member_permission_transaction,
        event: MemberPermissionTransactionEvent
    );
    component!(path: NFTTransaction, storage: nft_transaction, event: NFTTransactionEvent);
    component!(path: TokenTransaction, storage: token_transaction, event: TokenTransactionEvent);

    #[storage]
    struct Storage {
        deployer: ContractAddress,
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
    }
}

#[starknet::contract]
pub mod SpherreAccount {
    use spherre::{
        account_data::AccountData,
        actions::{
            change_threshold_tx::ChangeThresholdTransaction,
            member_permission_tx::MemberPermissionTransaction, member_tx::MemberTransaction,
            nft_tx::NFTTransaction, token_tx::TokenTransaction,
        },
        {errors::Errors},
    };
    use starknet::{
        {ContractAddress, contract_address_const},
        {storage::{StorableStoragePointerReadAccess, StoragePointerWriteAccess}},
    };

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
    }

    #[generate_trait]
    pub impl SpherreAccountImpl of ISpherreAccount {
        fn get_name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn get_description(self: @ContractState) -> ByteArray {
            self.description.read()
        }
    }
}

