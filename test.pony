use "ponytest"
use "collections"

actor Main is TestList
  new create(env:Env) =>
    PonyTest(env, this)
    let h = HashEq[USize].hash(1).usize()
    env.out.print(h.string())
    env.out.print((h and (8-1)).string())
  new make() => None
  fun tag tests(test: PonyTest) =>
    test(_TestCreate)
    test(_TestUpdate)
    test(_TestApply)
    test(_TestHasKey)

class iso _TestCreate is UnitTest
  fun name(): String => "create"
  fun apply(h: TestHelper) =>
    let m = RHMap[USize,USize,HashEq[USize]]
    h.assert_eq[USize](0, m.size())
    h.assert_eq[USize](6, m.space())

class iso _TestUpdate is UnitTest
  fun name(): String => "update"
  fun apply(h: TestHelper) ? =>
    let m = RHMap[USize,USize,HashEq[USize]]
    h.assert_is[(None | USize val)](None, m(1) = 1)
    h.assert_eq[USize](1, m.size())
    h.assert_eq[USize](6, m.space())
    for i in Range(0, 40) do
      m(i+10) = i+10
    end
    h.assert_eq[USize](41, m.size(), "m.size()")
    h.assert_eq[USize](48, m.space(), "m.space()")
    h.assert_eq[USize](1, m(1), "m(1)")
    h.assert_eq[USize](49, m(49), "m(49)")

class iso _TestApply is UnitTest
  fun name(): String => "apply"
  fun apply(h: TestHelper) ? =>
    let m = RHMap[USize,USize,HashEq[USize]]
    h.assert_is[(None | USize val)](None, m(1) = 1)
    h.assert_eq[USize](1, m.size())
    h.assert_eq[USize](6, m.space())
    h.assert_eq[USize](1, m(1), "m(1)")
    h.assert_is[(None | USize)](None, try m(0) end)

class iso _TestHasKey is UnitTest
  fun name(): String => "has_key"
  fun apply(h: TestHelper) =>
    let m = RHMap[USize,USize,HashEq[USize]]
    h.assert_is[(None | USize val)](None, m(1) = 1)
    h.assert_true(m.has_key(1))
    h.assert_false(m.has_key(2))
