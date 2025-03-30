// use spherre::errors::ThresholdError;
#[starknet::contract]
pub mod SpherreAccount {
    // Import OpenZeppelin Ownable component
    use openzeppelin::access::ownable::OwnableComponent;
    use spherre::{
        account_data::AccountData,
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
    // Add Ownable component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Implement Ownable mixin but don't embed it in the ABI
    // We'll expose the functions we need through our own implementation
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

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
        // Add Ownable storage
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
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
        // Add Ownable events
        #[flat]
        OwnableEvent: OwnableComponent::Event,
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

        // Initialize Ownable with the owner
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    pub impl SpherreAccountImpl of IAccount<ContractState> {
        fn get_name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn get_description(self: @ContractState) -> ByteArray {
            self.description.read()
        }

        fn get_account_details(self: @ContractState) -> AccountDetails {
            AccountDetails { name: self.name.read(), description: self.description.read() }
        }

        // Implement Ownable functions from the interface
        fn owner(self: @ContractState) -> ContractAddress {
            self.ownable.owner()
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self.ownable.transfer_ownership(new_owner);
        }

        fn renounce_ownership(ref self: ContractState) {
            self.ownable.renounce_ownership();
        }

        // Add functions that require owner access
        fn update_name(ref self: ContractState, new_name: ByteArray) {
            // Only the owner can update the name
            self.ownable.assert_only_owner();
            self.name.write(new_name);
        }

        fn update_description(ref self: ContractState, new_description: ByteArray) {
            // Only the owner can update the description
            self.ownable.assert_only_owner();
            self.description.write(new_description);
        }
    }
}
