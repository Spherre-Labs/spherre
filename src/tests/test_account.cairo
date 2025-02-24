fn deploy_spherre_account() -> ContractAddress {
    let owner: ContractAddress = starknet::contract_address_const::<0x123626789>();
    let mut constructor_calldata = ArrayTrait::new();
    let contract = declare("SpherreAccount").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}
