#[starknet::contract]
pub mod MockContract {
    use starknet::storage::StoragePointerReadAccess;
    use AccountData::InternalTrait;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::ContractAddress;
    use spherre::account_data::AccountData;

    component!(path: AccountData, storage: account_data, event: AccountDataEvent);

    #[abi(embed_v0)]
    impl AccountDataImpl = AccountData::AccountDataComponent<ContractState>;

    #[storage]
    struct Storage {
        // counter: u64,
        #[substorage(v0)]
        account_data: AccountData::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccountDataEvent: AccountData::Event,
    }

    impl AccountDataInternalImpl = AccountData::InternalImpl<ContractState>;

    #[constructor]
    fn constructor(ref self: ContractState) {
        // self.counter.write(0);
    }

    #[abi(embed_v0)]
    fn add_member(ref self: ContractState, member: ContractAddress) {
        self.account_data._add_member(member);
    }

    fn get_members(self: @ContractState) -> Array<ContractAddress> {
        let members = self.account_data.get_account_members();
        members
    }

    fn get_members_count(self: @ContractState) -> u64 {
        self.account_data.members_count.read()
    }
}