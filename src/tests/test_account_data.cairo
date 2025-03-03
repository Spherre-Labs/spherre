#[starknet::contract]
pub mod MockContract {
    use spherre::account_data::AccountDataComponent;
    component!(path: AccountDataComponent, storage: counter, event: CounterEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account_data: AccountDataComponent::Storage,
    }

    // #[event]
    // #[derive(Drop, starknet::Event)]
    // enum Event {
    // }

    #[abi(embed_v0)]
    impl AccountDataImpl = AccountDataComponent::AccountDataImpl<ContractState>;

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.members_count.write(0);
    }
}

#[cfg(test)]
mod test {
    use super::MockContract;
    use super::{IAccountDataComponentDispatcher, IAccountDataComponentDispatcherTrait};
    use starknet::{syscalls::deploy_syscall, ContractAddress};

    fn deploy() -> (IAccountDataComponentDispatcher, ContractAddress) {
        let (address, _) = deploy_syscall(
            MockContract::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();
        (IAccountDataComponentDispatcher { contract_address: address }, address)
    }

    
}