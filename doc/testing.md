# Testing

## Assembly generation

Testing generated assembly can be fragile. It is easy to get false failures or false passes. Ideally, we would have an emulator, and assert against expected outcomes rather than the exact assembly, as we often don't _really_ care about the exact assembly. However, absent that, it is better to test exact assembly.

Often updating tests that are false failures is trivial, while gaining confidence from tests that only test vague relationships like containing certain instructions, exact instruction positions, or the order of certain instructions, is difficult. In similar spirit to https://testing.googleblog.com/2014/07/testing-on-toilet-dont-put-logic-in.html, prefer to test exact generated assembly, even when it contains generation outside the scope of the test.

Assembly expectations should be built from the underly ASM model when that is not the model we are testing. Usually, testing a generator is testing its contract _between_ the model and the ASM lib. The ASM lib can get its own tests.

It is okay and sometimes preferable to add simple higher order assembly construction functions on top of this, but avoid the "logic in tests" problem.

Again, this makes tests readable and immediately gives confidence. These tests may eventually fail for irrelevant reasons, and risk becoming "change detectors" (https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html). However, correcting these cases is usually pretty simple. In the alternative, correcting can be more obtuse, or we are more likely to get false passes, which is fatal.

Of course, you do not have to assert about generated assembly at all if the test is about something else.
