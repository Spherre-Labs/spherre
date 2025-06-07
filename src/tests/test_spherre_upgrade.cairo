use crate::interfaces::iaccount::{IAccountDispatcher, IAccountDispatcherTrait};
use crate::interfaces::iaccount_data::{IAccountDataDispatcher, IAccountDataDispatcherTrait};
use crate::interfaces::ispherre::{ISpherreDispatcher, ISpherreDispatcherTrait};
use crate::spherre::Spherre;
use openzeppelin::upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use openzeppelin::upgrades::upgradeable::UpgradeableComponent::{Event as UpgradeEvent, Upgraded};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, EventSpyTrait, declare,
    get_class_hash, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
};
use spherre::tests::mocks::mock_spherreV2::{ISpherreV2Dispatcher, ISpherreV2DispatcherTrait};
use starknet::{ClassHash, ContractAddress, contract_address_const};


// --- Helper Functions ---

// Declare Contract Class and return the Class Hash
fn declare_contract(name: ByteArray) -> ClassHash {
    let declare_result = declare(name);
    let declared_contract = declare_result.unwrap().contract_class();
    *declared_contract.class_hash
}

// --- Setup ---

fn setup_test(owner: ContractAddress) -> (ISpherreDispatcher, ClassHash) {
    // Setup
    let declare_result_v1 = declare("Spherre").unwrap();
    let v1_contract_class = declare_result_v1.contract_class();

    let v2_class_hash = declare_contract("SpherreV2");

    let mut constructor_calldata = array![];
    owner.serialize(ref constructor_calldata);
    let (v1_contract_address, _) = v1_contract_class.deploy(@constructor_calldata).unwrap();

    let v1 = ISpherreDispatcher { contract_address: v1_contract_address };
    (v1, v2_class_hash)
}

// Deploy spherre account to get classhash
fn get_spherre_account_class_hash() -> ClassHash {
    let contract_class = declare("SpherreAccount").unwrap().contract_class();
    contract_class.class_hash.clone()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'Owner'>()
}
fn MEMBER_ONE() -> ContractAddress {
    contract_address_const::<'Member_one'>()
}
fn MEMBER_TWO() -> ContractAddress {
    contract_address_const::<'Member_two'>()
}

#[test]
fn test_upgrade_to_v2_success() {
    // Setup
    let owner: ContractAddress = OWNER();
    let (v1, v2_class_hash) = setup_test(owner);

    // Grant superadmin role to deployer
    let deployer: ContractAddress = contract_address_const::<'deployer'>();
    start_cheat_caller_address(v1.contract_address, owner);
    v1.grant_superadmin_role(deployer);
    stop_cheat_caller_address(v1.contract_address);

    // Spy on events, perform upgrade as deployer
    let mut spy = spy_events();
    start_cheat_caller_address(v1.contract_address, deployer);
    IUpgradeableDispatcher { contract_address: v1.contract_address }.upgrade(v2_class_hash);
    stop_cheat_caller_address(v1.contract_address);

    // Verify upgrade event
    let expected_upgrade_event = Spherre::Event::UpgradeableEvent(
        UpgradeEvent::Upgraded(Upgraded { class_hash: v2_class_hash }),
    );
    let expected_events = array![(v1.contract_address, expected_upgrade_event)];
    spy.assert_emitted(@expected_events);

    // Verify the upgrade was successful by checking the class hash
    let current_class_hash = get_class_hash(v1.contract_address);
    assert!(current_class_hash == v2_class_hash, "Contract not upgraded to v2");

    // Get V2 dispatcher
    let v2 = ISpherreV2Dispatcher { contract_address: v1.contract_address };

    // Test new V2 functionality
    assert_eq!(v2.get_version(), 2); // Default value
}

#[test]
#[should_panic(expected: ('Caller is not a superadmin',))]
fn test_upgrade_non_superadmin_fails() {
    // Setup
    let owner: ContractAddress = OWNER();
    let (v1, v2_class_hash) = setup_test(owner);

    // Attempt upgrade as a non-superadmin
    let non_superadmin: ContractAddress = contract_address_const::<'non_superadmin'>();
    start_cheat_caller_address(v1.contract_address, non_superadmin);
    IUpgradeableDispatcher { contract_address: v1.contract_address }.upgrade(v2_class_hash);
    stop_cheat_caller_address(v1.contract_address);
}

#[test]
fn test_upgrade_preserves_state() {
    // Setup
    let owner: ContractAddress = OWNER();
    let (v1, v2_class_hash) = setup_test(owner);
    let spherre_dispatcher = ISpherreDispatcher { contract_address: v1.contract_address };

    let account_classhash: ClassHash = get_spherre_account_class_hash();
    start_cheat_caller_address(v1.contract_address, owner);
    ISpherreDispatcher { contract_address: v1.contract_address }
        .update_account_class_hash(account_classhash);
    stop_cheat_caller_address(v1.contract_address);

    // Deploy a SpherreAccount in v1
    let name: ByteArray = "Test Spherre Account";
    let description: ByteArray = "Test Spherre Account Description";
    let members: Array<ContractAddress> = array![owner, MEMBER_ONE(), MEMBER_TWO()];
    let threshold: u64 = 2;
    let account_address = spherre_dispatcher
        .deploy_account(owner, name, description, members, threshold);

    // Capture initial state of the deployed account
    let account_data = IAccountDataDispatcher { contract_address: account_address };
    let account_info = IAccountDispatcher { contract_address: account_address };

    let is_member_initial = account_data.is_member(owner);
    let (threshold_initial, members_count_initial) = account_data.get_threshold();
    let name_initial = account_info.get_name();

    // Perform upgrade of the Spherre implementation
    start_cheat_caller_address(v1.contract_address, owner);
    IUpgradeableDispatcher { contract_address: v1.contract_address }.upgrade(v2_class_hash);
    stop_cheat_caller_address(v1.contract_address);

    // After upgrade verify if state is preserved
    let is_member_after = account_data.is_member(owner);
    let (threshold_after, members_count_after) = account_data.get_threshold();
    let name_after = account_info.get_name();

    assert_eq!(is_member_after, is_member_initial, "Membership was not preserved");
    assert_eq!(threshold_after, threshold_initial, "Threshold was not preserved");
    assert_eq!(members_count_after, members_count_initial, "Member count was not preserved");
    assert_eq!(name_after, name_initial, "Account name was not preserved");
}
