use crate::account::{SpherreAccount, SpherreAccount::AccountImpl};
use crate::interfaces::iaccount::{IAccountDispatcher, IAccountDispatcherTrait};
use openzeppelin_upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use openzeppelin_upgrades::upgradeable::UpgradeableComponent::{Event as UpgradeEvent, Upgraded};
use snforge_std::{
    declare, start_cheat_caller_address, get_class_hash, stop_cheat_caller_address,
    ContractClassTrait, DeclareResultTrait, spy_events, EventSpyTrait, EventSpyAssertionsTrait
};
use spherre::tests::mocks::mock_accountV2::{IAccountV2Dispatcher, IAccountV2DispatcherTrait};
use starknet::{ContractAddress, ClassHash, contract_address_const};


// --- Helper Function ---

// Declare Contract Class and return the Class Hash
fn declare_contract(name: ByteArray) -> ClassHash {
    let declare_result = declare(name);
    let declared_contract = declare_result.unwrap().contract_class();
    *declared_contract.class_hash
}

// --- Setup ---

fn setup_test() -> (IAccountDispatcher, ClassHash) {
    let declare_result_v1 = declare("SpherreAccount").unwrap();
    let v1_contract_class = declare_result_v1.contract_class();

    // Declare V2 and get only the class hash
    let v2_class_hash = declare_contract("SpherreAccountV2");

    // Deploy the initial version of the contract with constructor arguments
    let owner: ContractAddress = contract_address_const::<'owner'>();
    let deployer: ContractAddress = contract_address_const::<'deployer'>();
    let members: Array<ContractAddress> = array![
        contract_address_const::<'member1'>(), contract_address_const::<'member2'>()
    ];
    let threshold: u64 = 1;
    let name: ByteArray = "SpherreTestAccount";
    let description: ByteArray = "SpherreTestingAccount";

    let mut constructor_calldata = array![];

    deployer.serialize(ref constructor_calldata);
    owner.serialize(ref constructor_calldata);
    name.serialize(ref constructor_calldata);
    description.serialize(ref constructor_calldata);
    members.serialize(ref constructor_calldata);
    threshold.serialize(ref constructor_calldata);

    let (v1_contract_address, _) = v1_contract_class.deploy(@constructor_calldata).unwrap();

    let v1 = IAccountDispatcher { contract_address: v1_contract_address };
    (v1, v2_class_hash)
}

// --- Test Cases ---

#[test]
fn test_upgrade_to_v2_success() {
    // Setup
    let (v1, v2_class_hash) = setup_test();
    let mut spy = spy_events();

    let deployer: ContractAddress = contract_address_const::<'deployer'>();
    let name: ByteArray = "SpherreTestAccount";
    let description: ByteArray = "SpherreTestingAccount";

    // Verify initial state
    assert_eq!(v1.get_name(), name);
    assert_eq!(v1.get_description(), description);

    // Set caller as deployer
    start_cheat_caller_address(v1.contract_address, deployer);

    // Perform upgrade
    IUpgradeableDispatcher { contract_address: v1.contract_address }.upgrade(v2_class_hash);

    stop_cheat_caller_address(v1.contract_address);

    // Get emitted events
    let events = spy.get_events();
    assert(events.events.len() == 1, 'Upgrade event not emitted');

    // Verify upgrade event
    let expected_upgrade_event = SpherreAccount::Event::UpgradeableEvent(
        UpgradeEvent::Upgraded(Upgraded { class_hash: v2_class_hash })
    );

    let expected_events = array![(v1.contract_address, expected_upgrade_event)];
    spy.assert_emitted(@expected_events);

    // Verify the upgrade was successful by checking the class hash
    let current_class_hash = get_class_hash(v1.contract_address);
    assert!(current_class_hash == v2_class_hash, "Account Contract not upgraded");

    // Get V2 dispatcher
    let v2 = IAccountV2Dispatcher { contract_address: v1.contract_address };

    // Verify existing functionality works
    assert_eq!(v2.get_name(), name);
    assert_eq!(v2.get_description(), description);

    // Test new V2 functionality
    assert_eq!(v2.get_version(), 2); // Default value
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_upgrade_non_deployer_fails() {
    // Setup
    let (v1, v2_class_hash) = setup_test();
    let non_deployer: ContractAddress = contract_address_const::<'non_deployer'>();

    // Set caller as non-deployer
    start_cheat_caller_address(v1.contract_address, non_deployer);

    // Perform upgrade
    IUpgradeableDispatcher { contract_address: v1.contract_address }.upgrade(v2_class_hash);

    stop_cheat_caller_address(v1.contract_address);
}

#[test]
fn test_upgrade_preserves_state() {
    // Setup
    let (v1, v2_class_hash) = setup_test();
    let deployer: ContractAddress = contract_address_const::<'deployer'>();

    // Get initial values
    let original_name = v1.get_name();
    let original_deployer = v1.get_deployer();
    let original_description = v1.get_description();

    // Set caller as deployer
    start_cheat_caller_address(v1.contract_address, deployer);

    // Perform upgrade
    IUpgradeableDispatcher { contract_address: v1.contract_address }.upgrade(v2_class_hash);

    stop_cheat_caller_address(v1.contract_address);

    // Get V2 dispatcher
    let v2 = IAccountV2Dispatcher { contract_address: v1.contract_address };

    // Verify state is preserved
    let new_name = v2.get_name();
    let new_description = v2.get_description();
    let new_deployer = v2.get_deployer();

    assert_eq!(new_name, original_name);
    assert_eq!(new_deployer, original_deployer);
    assert_eq!(new_description, original_description);
}

#[test]
fn test_upgrade_emits_event() {
    // Setup
    let (v1, v2_class_hash) = setup_test();
    let mut spy = spy_events();

    let deployer: ContractAddress = contract_address_const::<'deployer'>();

    // Set caller as deployer
    start_cheat_caller_address(v1.contract_address, deployer);

    // Perform upgrade
    IUpgradeableDispatcher { contract_address: v1.contract_address }.upgrade(v2_class_hash);

    stop_cheat_caller_address(v1.contract_address);

    // Get emitted events
    let events = spy.get_events();
    assert(events.events.len() == 1, 'Upgrade event not emitted');

    // Verify upgrade event
    let expected_upgrade_event = SpherreAccount::Event::UpgradeableEvent(
        UpgradeEvent::Upgraded(Upgraded { class_hash: v2_class_hash })
    );

    // Assert that the event was emitted
    let expected_events = array![(v1.contract_address, expected_upgrade_event)];
    spy.assert_emitted(@expected_events);
}
