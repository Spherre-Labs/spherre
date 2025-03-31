// use spherre::errors::ThresholdError;
#[starknet::contract]
pub mod SpherreAccount {
    use AccountData::InternalTrait;
    use spherre::{
        account_data::AccountData, components::permission_control::PermissionControl,
        actions::{
            change_threshold_tx::ChangeThresholdTransaction,
            member_permission_tx::MemberPermissionTransaction, member_tx::MemberTransaction,
            nft_tx::NFTTransaction, token_tx::TokenTransaction,
        },
        {errors::Errors}, types::AccountDetails, interfaces::iaccount::IAccount,
    };
    use starknet::{
        {ContractAddress, contract_address_const},
        {storage::{StorableStoragePointerReadAccess, StoragePointerWriteAccess}},
    };

    component!(path: AccountData, storage: account_data, event: AccountDataEvent);
    component!(path: PermissionControl, storage: permission_control, event: PermissionControlEvent);
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

    #[abi(embed_v0)]
    impl AccountDataImpl = AccountData::AccountData<ContractState>;
    impl AccountDataInternalImpl = AccountData::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl PermissionControlImpl =
        PermissionControl::PermissionControl<ContractState>;
    impl PermissionControlInternalImpl = PermissionControl::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        deployer: ContractAddress,
        name: ByteArray,
        description: ByteArray,
        #[substorage(v0)]
        account_data: AccountData::Storage,
        #[substorage(v0)]
        permission_control: PermissionControl::Storage,
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
        PermissionControlEvent: PermissionControl::Event,
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
        assert(members.len() > 0, Errors::NON_ZERO_MEMBER_LENGTH);
        assert(threshold > 0, Errors::NON_ZERO_THRESHOLD);
        assert((members.len()).into() >= threshold, Errors::ERR_INVALID_MEMBER_THRESHOLD);

        self.name.write(name);
        self.description.write(description);
        let len_member = members.len();
        for index in 0
            ..len_member {
                let member = *members.at(index);
                self.account_data._add_member(member);
                self.permission_control.assign_all_permissions(member);
            };
        self.account_data.set_threshold(threshold);
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
    }
}
