Req.default_options(plug: {Req.Test, JosjobRag.AtomicClient})

Code.require_file("support/fake_vector_store.ex", __DIR__)
Code.require_file("support/fake_embeddings.ex", __DIR__)

ExUnit.start()
