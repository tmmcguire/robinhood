use "debug"
use "collections"

// http://codecapsule.com/2013/11/11/robin-hood-hashing/
// http://codecapsule.com/2013/11/17/robin-hood-hashing-backward-shift-deletion/
// http://www.sebastiansylvan.com/post/robin-hood-hashing-should-be-your-default-hash-table-implementation/
// http://www.sebastiansylvan.com/post/more-on-robin-hood-hashing-2/
// http://www.pvk.ca/Blog/more_numerical_experiments_in_hashing.html

// -------------------------------------

primitive _EmptyBucket

// -------------------------------------

class _FullBucket[K,V,H: HashFunction[K] val]
  var _key: (K | None)
  var _value: (V | None)
  let hash: USize

  new create(k: K, v: V, h: USize) =>
    _key = consume k
    _value = consume v
    hash = h

  fun eq(k: box->K!, h: USize): Bool =>
    try
      if _key is None then
        return false
      else
        return (hash == h) and H.eq(key(), k)
      end
    end
    false

  fun bucket(mask: USize): USize =>
    hash and mask

  fun key(): this->K ? => _key as this->K

  fun value(): this->V ? => _value as this->V

  fun ref destroy(): (K^,V^) ? =>
    let k = _key = None
    let v = _value = None
    (k as K^, v as V^)

// -------------------------------------

class RHMap[K,V,H: HashFunction[K] val]
  let _lf_numerator: USize = 3
  let _lf_denominator: USize = 4
  var _size: USize = 0
  var _array: Array[(_EmptyBucket | _FullBucket[K,V,H])]

  new create(prealloc: USize = 6) =>
    let len = ((prealloc * _lf_denominator) / _lf_numerator).next_pow2().max(8)
    _array = _array.create(len)
    for i in Range(0, len) do
      _array.push(_EmptyBucket)
    end

  fun size(): USize =>
    _size

  fun space(): USize =>
    (_array.size() * _lf_numerator) / _lf_denominator

  fun has_key(k: box->K!): Bool =>
    (_, let found: Bool) = _search(k)
    found

  fun apply(k: box->K!): this->V ? =>
    (let i: USize, let found: Bool) = _search(k)
    if found then
      return (_array(i) as _FullBucket[K,V,H]).value() as this->V
    else
      error
    end

  fun ref update(key: K, value: V): (V^ | None) =>
    try _update(consume key, consume value) end

  fun ref insert(key: K, value: V): V ? =>
    let k = key
    this(consume key) = consume value
    this(k)

  fun ref remove(key: box->K!): (K^, V^) ? =>
    let mask = _array.size() - 1
    (let i: USize, let found: Bool) = _search(key)
    if found then
      let stop = _stop(i)
      let b = _array(i) = _EmptyBucket
      var j = i
      var k = (j + 1) and mask
      while k != stop do
        _array(j) = _array(k) = _EmptyBucket
        j = k
        k = (k + 1) and mask
      end
      (b as _FullBucket[K,V,H]).destroy()
    else
      error
    end

  fun print_dib(env: Env) =>
    env.out.print("DIB:")
    var i: USize = 0
    for entry in _array.values() do
      match entry
      | _EmptyBucket =>
      env.out.print(" -")
      | let b: _FullBucket[K,V,H] => // (_,_,_,let initial: USize) =>
      env.out.print(" " + i.string() + " " + dib(i, b.bucket(_array.size() - 1)).string())
      end
      i = i + 1
    end

  fun dib(current: USize, initial: USize): USize =>
    if current >= initial then
      current - initial
    else
      (_array.size() + current) - initial
    end

  fun _search(key: box->K!): (USize, Bool) =>
    let mask = _array.size() - 1
    let hash = H.hash(key).usize()
    let bucket = hash and mask
    var i = bucket
    var found = false
    try
      repeat
        match _array(i)
        | _EmptyBucket =>
          break
        | let b: _FullBucket[K,V,H] =>
          if dib(i, b.bucket(mask)) < dib(i, bucket) then
            break
          elseif b.eq(key, hash) then
            found = true
            break
          end
        end
        i = (i + 1) and mask
      until i == bucket end
    end
    (i, found)

  fun _stop(initial: USize): USize ? =>
    let mask = _array.size() - 1
    var i = (initial + 1) and mask
    repeat
      match _array(i)
      | _EmptyBucket =>
        return i
      | let b: _FullBucket[K,V,H] =>
        if dib(i, b.bucket(mask)) == 0 then
          return i
        end
      end
      i = (i + 1) and mask
    until i == initial end
    error

  fun ref _update(key: K, value: V): (V^ | None) ? =>
    let mask = _array.size() - 1
    var k = consume key
    var v = consume value
    var hash = H.hash(k).usize()
    var bucket = hash and mask
    var i = bucket
    repeat
      match _array(i)
      | _EmptyBucket =>
        _array(i) = _FullBucket[K,V,H](consume k, consume v, hash)
        _size = _size + 1
        if _size > space() then
          _resize()
        end
        return None
      | let b: _FullBucket[K,V,H] =>
        if b.eq(k, hash) then
          _array(i) = _FullBucket[K,V,H](consume k, consume v, hash)
          return b.destroy() as (_, V^)
        elseif dib(i, b.bucket(mask)) < dib(i, bucket) then
          _array(i) = _FullBucket[K,V,H](consume k, consume v, hash)
          hash = b.hash
          bucket = b.bucket(mask)
          (let k':K, let v':V) = b.destroy()
          k = consume k'
          v = consume v'
        end
      end
      i = (i + 1) and mask
    until i == bucket end
    None

  fun ref _resize() =>
    try
      var new_map = RHMap[K,V,H].create( size() * 2 )
      for i in Range(0, _array.size()) do
        let bucket = _array(i) = _EmptyBucket
        match consume bucket
        | _EmptyBucket => continue
        | let b: _FullBucket[K,V,H] =>
          (let k:K, let v:V) = b.destroy()
          new_map._update(consume k, consume v)
        end
      end
      _size = new_map._size = _size
      _array = new_map._array = _array
    end
