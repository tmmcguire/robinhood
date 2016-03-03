use "debug"
use "collections"

// -------------------------------------

primitive _EmptyBucket

// -------------------------------------

class _FullBucket[K,V,H: HashFunction[K] val]
  var _key: (K | None)
  var _value: (V | None)
  let hash: USize
  let bucket: USize

  new create(k: K, v: V, h: USize, b: USize) =>
    _key = consume k
    _value = consume v
    hash = h
    bucket = b

  fun eq(k: box->K!, h: USize): Bool =>
    try
      if _key is None then
        return false
      else
        return (hash == h) and H.eq(key(), k)
      end
    end
    false

  fun key(): this->K ? => _key as this->K

  fun value(): this->V ? => _value as this->V

  fun ref destroy(): (K^,V^) ? =>
    let k = _key = None
    let v = _value = None
    (k as K^, v as V^)

// -------------------------------------

class RHMap[K,V,H: HashFunction[K] val]
  var _size: USize = 0
  var _array: Array[(_EmptyBucket | _FullBucket[K,V,H])]

  new create(prealloc: USize = 6) =>
    let len = ((prealloc * 4) / 3).next_pow2().max(8)
    _array = _array.create(len)
    for i in Range(0, len) do
      _array.push(_EmptyBucket)
    end

  fun size(): USize =>
    _size

  fun space(): USize =>
    (_array.size() * 3) / 4

  fun apply(k: box->K!): this->V ? =>
    (let i: USize, let found: Bool) = _search(k)
    if not found then
      error
    else
      return (_array(i) as _FullBucket[K,V,H]).value() as this->V
    end

  fun has_key(k: box->K!): Bool =>
    (_, let found: Bool) = _search(k)
    found

  fun ref update(key: K, value: V): (V^ | None) =>
    try _update(consume key, consume value) end

  fun print_dib(env: Env) =>
    env.out.print("DIB:")
    var i: USize = 0
    for entry in _array.values() do
      match entry
      | _EmptyBucket =>
      env.out.print(" -")
      | let b: _FullBucket[K,V,H] => // (_,_,_,let initial: USize) =>
      env.out.print(" " + i.string() + " " + dib(i, b.bucket).string())
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
        | _EmptyBucket => break
        | let b: _FullBucket[K,V,H] =>
          if b.eq(key, hash) then
            found = true
            break
          end
        end
        i = (i + 1) % _array.size()
      until i == bucket end
    end
    (i, found)

  fun ref _update(key: K, value: V): (V^ | None) ? =>
    if (size() + 1) > space() then
      _resize()
    end
    let mask = _array.size() - 1
    var k = consume key
    var v = consume value
    var hash = H.hash(k).usize()
    var bucket = hash and mask
    var i = bucket
    repeat
      match _array(i)
      | _EmptyBucket =>
        _array(i) = _FullBucket[K,V,H](consume k, consume v, hash, bucket)
        _size = _size + 1
        return None
      | let b: _FullBucket[K,V,H] =>
        if b.eq(k, hash) then
          _array(i) = _FullBucket[K,V,H](consume k, consume v, hash, bucket)
          return b.destroy() as (_, V^)
        elseif dib(i, b.bucket) < dib(i, bucket) then
          _array(i) = _FullBucket[K,V,H](consume k, consume v, hash, bucket)
          hash = b.hash
          bucket = b.bucket
          (let k':K, let v':V) = b.destroy()
          k = consume k'
          v = consume v'
        end
      end
      i = (i + 1) % _array.size()
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
