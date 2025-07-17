mod reset_will_duration {
    use starknet::ContractAddress;
    use snforge_std::{declare, deploy, start_prank, set_block_timestamp};
    
    use crate::interfaces::iaccount_data::{ IAccountDataDispatcher, IAccountDataDispatcherTrait };


    const THIRTY_DAYS: u64 = 30 * 24 * 60 * 60;  // 2,592,000 seconds
    const NINETY_DAYS: u64 = 90 * 24 * 60 * 60;  // 7,776,000 seconds

    #[test]
    fn test_successful_duration_reset() {
        // 1. Deploy contract and create interface dispatcher
        let contract_address = deploy("account_data");
        let dispatcher = IAccountDataDispatcher { contract_address };

        // 2. Test member address (contract assumes caller context, but we'll simulate)
        let test_member: ContractAddress = contract_address;  // simulate caller is the contract deployer

        // 3. Set starting time and initialize state
        let start_time = 1_000;
        set_block_timestamp(start_time);

        // 4. Manually simulate previous setup:
        // Normally, your contract would already have logic to call update_smart_will(...)
        // so we assume this step already happened before this test.
        // The member has a will address and its duration is set.

        // 5. Advance to a timestamp within reset window (e.g., 29 days before expiry)
        let reset_window_time = start_time + NINETY_DAYS - THIRTY_DAYS + 86_400;
        set_block_timestamp(reset_window_time);

        // 6. Call reset_will_duration (the actual functionality under test)
        dispatcher.reset_will_duration(test_member);

        // 7. Verify: new expiration = old_expiry + DEFAULT_WILL_DURATION (NINETY_DAYS)
        let new_expiry = dispatcher.get_member_will_duration(test_member);
        let expected_expiry = (start_time + NINETY_DAYS) + NINETY_DAYS;

        assert(new_expiry == expected_expiry, 'Will duration not properly extended');
    }
}
