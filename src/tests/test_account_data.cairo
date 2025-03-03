use starknet::contract_address_const;
use starknet::ContractAddress;

use snforge_std::{
    declare, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait, DeclareResultTrait
};

use spherre::interfaces::iaccount_data::{IAccountDataDispatcher, IAccountDataDispatcherTrait};

fn zero_address() -> ContractAddress {
    contract_address_const::<0>()
}

fn new_member() -> ContractAddress {
    contract_address_const::<'new_member'>()
}

fn another_new_member() -> ContractAddress {
    contract_address_const::<'another_new_member'>()
}

fn third_member() -> ContractAddress {
    contract_address_const::<'third_member'>()
}

fn member() -> ContractAddress {
    contract_address_const::<'member'>()
}

fn deploy_mock_contract() -> ContractAddress {
    let contract_class = declare("MockContract").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    contract_address
}

#[test]
#[should_panic(expected: 'Zero Address Caller')]
fn test_zero_address_caller_should_fail() {
    let zero_address = zero_address();
    let member = member();
    let contract_address = deploy_mock_contract();

    let mock_contract_dispatcher = IAccountDataDispatcher { contract_address };
    // let mock_contract_internal_dispatcher = IAccountDataDispatcherTrait { contract_address };
    start_cheat_caller_address(contract_address, member);
    mock_contract_dispatcher.add_member(zero_address);
    stop_cheat_caller_address(contract_address);
}

// This indirectly tests get_members_count

#[test]
fn test_add_member() {
    let new_member = new_member();
    let member = member();
    let contract_address = deploy_mock_contract();

    let mock_contract_dispatcher = IAccountDataDispatcher { contract_address };
    start_cheat_caller_address(contract_address, member);
    mock_contract_dispatcher.add_member(new_member);
    stop_cheat_caller_address(contract_address);

    let count = mock_contract_dispatcher.get_members_count();
    assert(count == 1, 'Member not added');
}

#[test]
fn test_get_members() {
    let new_member = new_member();
    let another_new_member = another_new_member();
    let third_member = third_member();
    let member = member();
    let contract_address = deploy_mock_contract();

    let mock_contract_dispatcher = IAccountDataDispatcher { contract_address };
    start_cheat_caller_address(contract_address, member);
    mock_contract_dispatcher.add_member(new_member);
    mock_contract_dispatcher.add_member(another_new_member);
    mock_contract_dispatcher.add_member(third_member);
    stop_cheat_caller_address(contract_address);

    let count = mock_contract_dispatcher.get_members_count();
    assert(count == 3, 'Members not added');
    let members = mock_contract_dispatcher.get_account_members();
    let member_0 = *members.at(0);
    let member_1 = *members.at(1);
    let member_2 = *members.at(2);
    assert(member_0 == new_member, 'First addition unsuccessful');
    assert(member_1 == another_new_member, 'second addition unsuccessful');
    assert(member_2 == third_member, 'third addition unsuccessful');
}