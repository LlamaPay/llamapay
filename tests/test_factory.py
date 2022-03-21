def test_create_llama_pay_is_deterministic(alice, factory, token):
    expected_address, is_deployed = factory.getLlamaPayContractByToken(token)
    assert is_deployed is False

    tx = factory.createLlamaPayContract(token, {"from": alice})
    assert tx.events["LlamaPayCreated"].values() == [token, expected_address]
