#[starknet::contract]
pub mod MockContract {
    use super::AccountData;


    component!(path: AccountData, storage: AccountStorage, event: AccEvent);

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        AccountStorage: AccountData::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AccEvent: AccountData::Event,
    }

    #[abi(embed_v0)]
    pub impl ThresholdHandlerImpl = AccountData::ThresholdHandler<ContractState>;

    pub impl ThresholdInfoImpl = AccountData::ThresholdSetterImpl<ContractState>;
}


pub mod test {
    use super::MockContract;
    use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
    use crate::interfaces::iaccount_data::{
        IThresholdHandlerDispatcher, IThresholdHandlerDispatcherTrait,
    };
    use spherre::account_data::AccountData::ThresholdSetterTrait;
    use core::starknet::storage::StoragePointerWriteAccess;


    fn contract_dispatch(name: ByteArray) -> IThresholdHandlerDispatcher {
        let contract = declare(name).unwrap().contract_class();
        let (contract_address, _) = contract.deploy(@array![]).unwrap();
        let dispatcher = IThresholdHandlerDispatcher { contract_address };
        dispatcher
    }

    #[test]
    fn get_test_pass() {
        // This test is meant to pass and assert the value of get function in the interface;
        let mut dispatcher = contract_dispatch("MockContract");
        let threshold = dispatcher.get();
        assert(threshold == (0, 0), 'balance ==0');
    }

    #[test]
    fn get_test_fail() {
        // This test is meant to fail because the data is false;
        let mut dispatcher = contract_dispatch("MockContract");
        let threshold = dispatcher.get();
        assert(threshold == (0, 1), 'test passed');
    }

    type TestingState = super::AccountData::ComponentState<MockContract::ContractState>;

    impl TestingStateDefault of Default<TestingState> {
        fn default() -> TestingState {
            spherre::account_data::AccountData::component_state_for_testing()
        }
    }

    #[test]
    fn test_private_functions_pass() {
        // This test is supposed to pass because threshold is less than members_count;
        let mut counter: TestingState = Default::default();
        counter.members_count.write(15);
        counter.set_threshold(12);
    }

    #[test]
    fn test_private_functions_fail() {
        // This test is supposed to fail because members_count is less than threshold;
        let mut counter: TestingState = Default::default();
        counter.members_count.write(10);
        counter.set_threshold(12);
    }

    #[test]
    fn emit_test() {
        // tests emit, to see if there is an output

        let mut counter: TestingState = Default::default();
        counter.add_threshold_info(threshold: 12, date_updated: '24-01-25');
    }
}
