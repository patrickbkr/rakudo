
sub METAOP_ASSIGN(\op) {
    -> Mu \a, Mu \b { a = op.( a // op.(), b) }
}

sub METAOP_TEST_ASSIGN:<//>(\lhs, $rhs) is rw { lhs // (lhs = $rhs()) }
sub METAOP_TEST_ASSIGN:<||>(\lhs, $rhs) is rw { lhs || (lhs = $rhs()) }
sub METAOP_TEST_ASSIGN:<&&>(\lhs, $rhs) is rw { lhs && (lhs = $rhs()) }
sub METAOP_TEST_ASSIGN:<andthen>(\lhs, $rhs) is rw { lhs andthen (lhs = $rhs()) }
sub METAOP_TEST_ASSIGN:<orelse>(\lhs, $rhs) is rw { lhs orelse (lhs = $rhs()) }

sub METAOP_NEGATE(\op) {
    -> Mu \a, Mu \b { !op.(a ,b) }
}

sub METAOP_REVERSE(\op) {
    -> |args { op.(|args.reverse) }
}

sub METAOP_CROSS(\op, &reduce) {
    return &infix:<X> if op === &infix:<,>;

    -> |lol {
        my $rop = lol.elems == 2 ?? op !! &reduce(op);
        my $Inf = False;
        my @loi = eager for ^lol.elems -> $i {
            my \elem = lol[$i];         # can't use mapping here, mustn't flatten
            $Inf = True if elem.is-lazy;

            nqp::iscont(elem) ?? (elem,).iterator
              !! nqp::istype(elem, Iterable)
                ?? elem.iterator
                !! elem.list.iterator;
        }
        my Mu $cache := nqp::list();
        my int $i = 0;
        for ^lol.elems {
            $i = $_;
            my Mu $rpa := nqp::list();
            nqp::bindpos($cache, $i, $rpa);
        }
        my int $n = lol.elems - 1;
        my $j = 0;
        my @j;
        my @v;

        $i = 0;
        gather {
            while $i >= 0 {
                my Mu $sublist := nqp::atpos($cache, $i);
                if $j < nqp::elems($sublist) {
                    my Mu $o := nqp::atpos($sublist, $j);
                    @v[$i] := $o;
                    $j = $j + 1;
                    if $i >= $n { take lol.elems == 2 ?? $rop(|@v) !! $rop(@v); }
                    else { $i = $i + 1; @j.push($j); $j = 0; }
                }
                elsif (my \value = @loi[$i].pull-one) !=:= IterationEnd {
                    nqp::bindpos($sublist, $j, value);
                    redo;
                }
                else {
                    $i = $i - 1;
                    if $i { $j = @j.pop if $i > 0 }  # continue previous dimension where we left off
                    else  {
                        $j = 0;
                        my Mu $sublist := nqp::atpos($cache,$i);
                        nqp::pop($sublist);          # don't cache 1st dimension (could be infinite)
                    }
                }
            }
        }
    }
}

sub METAOP_ZIP(\op, &reduce) {
    -> |lol {
        my $arity = lol.elems;
        my $rop = $arity == 2 ?? op !! &reduce(op);
        my @loi = eager for ^lol.elems -> $i {
            my \elem = lol[$i];         # can't use mapping here, mustn't flatten

            nqp::istype(elem, Iterable)
                ?? elem.iterator
                !! elem.list.iterator;
        }
        gather {
            loop {
                my \z = @loi.map: {
                    my \value = .pull-one;
                    last if value =:= IterationEnd;
                    value
                };
                my $z = List.from-iterator(z.iterator);
                $z.eager;
                last if $z.elems < $arity;
                take-rw $arity == 2 ?? $rop(|$z) !! $rop(@$z);
            }
        }
    }
}

proto sub METAOP_REDUCE_LEFT(|) { * }
multi sub METAOP_REDUCE_LEFT(\op, \triangle) {
#?if jvm
    my $ :=
#?endif
    sub (\iterablish) {
        my \source = nqp::istype(iterablish, Iterable)
            ?? iterablish.iterator
            !! iterablish.list.iterator;

        my \first = source.pull-one;
        return () if first =:= IterationEnd;

        my $result := first;
        GATHER({
            take first;
            until (my \value = source.pull-one) =:= IterationEnd {
                take ($result := op.($result, value));
            }
        });
    }
}

multi sub METAOP_REDUCE_LEFT(\op) {
#?if jvm
    my $ :=
#?endif
    sub (\iterablish) {
        my \iter = nqp::istype(iterablish, Iterable)
            ?? iterablish.iterator
            !! iterablish.list.iterator;
        my \first = iter.pull-one;
        return op.() if first =:= IterationEnd;

        my \second = iter.pull-one;
        return op.count <= 1 ?? op.(first) !! first if second =:= IterationEnd;

        my $result := op.(first, second);
        until (my \value = iter.pull-one) =:= IterationEnd {
            $result := op.($result, value);
        }
        $result;
    }
}

proto sub METAOP_REDUCE_RIGHT(|) { * }
multi sub METAOP_REDUCE_RIGHT(\op, \triangle) {
#?if jvm
    my $ :=
#?endif
    sub (*@values) {
        my \iter = @values.reverse.iterator;
        my $result := iter.pull-one;
        return () if $result =:= IterationEnd;

        gather {
            take $result;
            while (my $elem := iter.pull-one) !=:= IterationEnd {
                take $result := op.($elem, $result)
            }
        }
    }
}
multi sub METAOP_REDUCE_RIGHT(\op) {

#?if jvm
    my $ :=
#?endif
    sub (*@values) {
        my \iter = @values.reverse.iterator;
        my \first = iter.pull-one;
        return op.() if first =:= IterationEnd;

        my \second = iter.pull-one;
        return op.(first) if second =:= IterationEnd;

        my $result := op.(second, first);
        until (my \value = iter.pull-one) =:= IterationEnd {
            $result := op.(value, $result);
        }
        $result;
    }
}

proto sub METAOP_REDUCE_LIST(|) { * }
multi sub METAOP_REDUCE_LIST(\op, \triangle) {
#?if jvm
    my $ :=
#?endif
    sub (*@values) {

        my \res = GATHER({
            my @list;
            for @values -> \v {
                @list.push(v);
                take op.(|@list);
            }
        });
        @values.is-lazy ?? res.lazy !! res;
    }
}
multi sub METAOP_REDUCE_LIST(\op) {
#?if jvm
    my $ :=
#?endif
    sub (*@values) { op.(|@values) }
}

proto sub METAOP_REDUCE_LISTINFIX(|) { * }
multi sub METAOP_REDUCE_LISTINFIX(\op, \triangle) {
#?if jvm
    my $ :=
#?endif
    sub (|values) {
        my \p = values[0];
        return () unless p.elems;

        my int $i;
        my \res = GATHER({
            my @list;
            while $i < p.elems {
                @list.push(p[$i]);
                $i = $i + 1;
                take op.(|@list);
            }
        });
        p.is-lazy ?? res.lazy !! res;
    }
}
multi sub METAOP_REDUCE_LISTINFIX(\op) {
#?if jvm
    my $ :=
#?endif
    sub (|values) {
        my \p = values[0];
        nqp::iscont(p[0])
          ?? op.(|p.map({nqp::decont($_).list}))
          !! op.(|p);
    }
}

proto sub METAOP_REDUCE_CHAIN(|) { * }
multi sub METAOP_REDUCE_CHAIN(\op, \triangle) {
#?if jvm
    my $ :=
#?endif
    sub (*@values) {
        my $state = True;
        my \iter = @values.iterator;
        my Mu $current = iter.pull-one;
        gather {
            take $state;
            while $state && (my $next := iter.pull-one) !=:= IterationEnd {
                $state = op.($current, $next);
                take $state;
                $current := $next;
            }
            unless $state {
                while (my \v = iter.pull-one) !=:= IterationEnd {
                    take False;
                }
            }
        }
    }
}
multi sub METAOP_REDUCE_CHAIN(\op) {
#?if jvm
    my $ :=
#?endif
    sub (*@values) {
        my $state := True;
        my \iter = @values.iterator;
        my $current := iter.pull-one;
        return True if $current =:= IterationEnd;

        while (my $next := iter.pull-one) !=:= IterationEnd {
            $state := op.($current, $next);
            return $state unless $state;
            $current := $next;
        }
        $state;
    }
}

sub METAOP_REDUCE_XOR(\op, $triangle?) {
    X::NYI.new(feature => 'xor reduce').throw;
}

sub METAOP_HYPER(\op, *%opt) {
    -> Mu \a, Mu \b { HYPER(op, a, b, |%opt) }
}

proto sub METAOP_HYPER_POSTFIX(|) {*}
multi sub METAOP_HYPER_POSTFIX(\obj, \op) {
    op.?nodal      # rarely true for prefixes
        ?? nodemap(op, obj)
        !! deepmap(op, obj);
}
multi sub METAOP_HYPER_POSTFIX(\obj, \args, \op) {
    op.?nodal
        ?? nodemap( -> \o { op.(o,|args) }, obj )
        !! deepmap( -> \o { op.(o,|args) }, obj );
}

sub METAOP_HYPER_PREFIX(\op, \obj) {
    op.?nodal      # rarely true for prefixes
        ?? nodemap(op, obj)
        !! deepmap(op, obj);
}

sub METAOP_HYPER_CALL(\list, |args) { deepmap(-> $c { $c(|args) }, list) }

proto sub HYPER(|) { * }

multi sub HYPER(&op, \left, \right, :$dwim-left, :$dwim-right) {
    op(left, right);
}

multi sub HYPER(&op, Associative:D \left, Associative:D \right, :$dwim-left, :$dwim-right) {
    my %keyset;
    if !$dwim-left {
        %keyset{$_} = 1 for left.keys;
    }
    else {
        %keyset{$_} = 1 if right.EXISTS-KEY($_) for left.keys;
    }
    if !$dwim-right {
        %keyset{$_} = 1 for right.keys;
    }
    my @keys = %keyset.keys;
    my $type = left.WHAT;
    my \result := $type.new;
    result = @keys Z=> HYPER(&op, left{@keys}, right{@keys}, :$dwim-left, :$dwim-right);
    nqp::iscont(left) ?? result.item !! result;
}

multi sub HYPER(&op, Associative:D \left, \right, :$dwim-left, :$dwim-right) {
    my @keys = left.keys;
    my $type = left.WHAT;
    my \result := $type.new;
    result = @keys Z=> HYPER(&op, left{@keys}, right, :$dwim-left, :$dwim-right);
    nqp::iscont(left) ?? result.item !! result;
}

multi sub HYPER(&op, \left, Associative:D \right, :$dwim-left, :$dwim-right) {
    my @keys = right.keys;
    my $type = right.WHAT;
    my \result := $type.new;
    result = @keys Z=> HYPER(&op, left, right{@keys}, :$dwim-left, :$dwim-right);
    nqp::iscont(right) ?? result.item !! result;
}

# XXX Should really be Iterable:D by spec, but then it doesn't work with Parcel
multi sub HYPER(&operator, Positional:D \left, \right, :$dwim-left, :$dwim-right) {
    my @result;
    X::HyperOp::Infinite.new(:side<left>, :&operator).throw if left.is-lazy;
    my int $elems = left.elems;
    X::HyperOp::NonDWIM.new(:&operator, :left-elems($elems), :right-elems(1)).throw
        unless $elems == 1 or $elems > 1 and $dwim-right or $elems == 0 and $dwim-left || $dwim-right;
    my \lefti := left.iterator;
    my int $i = 0;
    until (my \value := lefti.pull-one) =:= IterationEnd {
        @result[$i++] := HYPER(&operator, value, right, :$dwim-left, :$dwim-right);
    }
    # Coerce to the original type if it's a subtype of List
    my $type = nqp::istype(left, List) ?? left.WHAT !! List;
    nqp::iscont(left) ?? $type(|@result.eager).item !! $type(|@result.eager)
}

multi sub HYPER(&operator, \left, Positional:D \right, :$dwim-left, :$dwim-right) {
    my @result;
    X::HyperOp::Infinite.new(:side<right>, :&operator).throw if right.is-lazy;
    my int $elems = right.elems;
    X::HyperOp::NonDWIM.new(:&operator, :left-elems(1), :right-elems($elems)).throw
        unless $elems == 1 or $elems > 1 and $dwim-left or $elems == 0 and $dwim-left || $dwim-right;
    my \righti := right.iterator;
    my int $i = 0;
    until (my \value := righti.pull-one) =:= IterationEnd {
        @result[$i++] := HYPER(&operator, left, value, :$dwim-left, :$dwim-right);
    }
    # Coerce to the original type if it's a subtype of List
    my $type = nqp::istype(right, List) ?? right.WHAT !! List;
    nqp::iscont(right) ?? $type(|@result.eager).item !! $type(|@result.eager)
}

multi sub HYPER(&operator, Iterable:D \left, Iterable:D \right, :$dwim-left, :$dwim-right) {
    my \left-iterator = left.iterator;
    my \right-iterator = right.iterator;

    # Check whether any side is lazy. They must not be to proceed.
    if left-iterator.is-lazy {
        X::HyperOp::Infinite.new(:side<both>, :&operator).throw if right-iterator.is-lazy;
        X::HyperOp::Infinite.new(:side<left>, :&operator).throw if not $dwim-left or $dwim-right;
    }
    X::HyperOp::Infinite.new(:side<right>, :&operator).throw if right-iterator.is-lazy and
        (not $dwim-right or $dwim-left);

    my class DwimIterator does Iterator {
        has $!source;
        has $!buffer;
        has $!ended;
        has $!whatever;
        has $!i;
        has $!elems;
        method new(\source) {
            my $iter := self.CREATE;
            nqp::bindattr($iter, self, '$!source', source);
            nqp::bindattr($iter, self, '$!buffer', IterationBuffer.new);
            nqp::bindattr($iter, self, '$!ended', False);
            nqp::bindattr($iter, self, '$!whatever', False);
            nqp::bindattr($iter, self, '$!i', 0);
            nqp::bindattr($iter, self, '$!elems', 0);
            $iter
        }
        method pull-one() is rw {
            if ($!ended) {
                if ($!whatever) {
                    $!buffer.AT-POS($!elems - 1);
                }
                else {
                    $!buffer.AT-POS((($!i := $!i + 1) - 1) % $!elems);
                }
            }
            else {
                my \value := $!source.pull-one;
                if value =:= IterationEnd {
                    $!ended := True;
                    $!elems == 0 ?? value !! self.pull-one()
                }
                elsif nqp::istype(value, Whatever) {
                    $!whatever := True;
                    $!ended := True;
                    self.pull-one()
                }
                else {
                    $!elems := $!elems + 1;
                    $!buffer.push(value);
                    value
                }
            }
        }
        method ended() { $!ended }
        method count-elems() {
            unless ($!ended) {
                $!elems := $!elems + 1 until $!source.pull-one =:= IterationEnd;
            }
            $!elems
        }
    }

    my \lefti  :=  DwimIterator.new(left-iterator);
    my \righti :=  DwimIterator.new(right-iterator);

    my \result := IterationBuffer.new;
    loop {
        my \leftv := lefti.pull-one;
        my \rightv := righti.pull-one;

        X::HyperOp::NonDWIM.new(:&operator, :left-elems(lefti.count-elems), :right-elems(righti.count-elems)).throw
            if !$dwim-left and !$dwim-right and (lefti.ended != righti.ended);

        last if ($dwim-left and $dwim-right) ?? (lefti.ended and righti.ended) !!
               (($dwim-left or lefti.ended) and ($dwim-right or righti.ended));
        last if $++ == 0 and ($dwim-left and lefti.ended or $dwim-right and righti.ended);

        result.push(HYPER(&operator, leftv, rightv, :$dwim-left, :$dwim-right));
    }

    # Coerce to the original type
    my $type = nqp::istype(left, List) ?? left.WHAT !! List; # keep subtypes of List
    my \retval = $type.new;
    nqp::bindattr(retval, List, '$!reified', result);
    nqp::iscont(left) ?? retval.item !! retval;
}

multi sub HYPER(\op, \obj) {
    op.?nodal
        ?? nodemap(op, obj)
        !! deepmap(op,obj);
}

proto sub deepmap(|) { * }

multi sub deepmap(\op, \obj) {
    #my Mu $rpa := nqp::list();
    #my \objs := obj.list;
    # as a wanted side-effect is-lazy reifies the list
    #fail X::Cannot::Lazy.new(:action('deepmap')) if objs.is-lazy;
    my \iterable = obj.DEFINITE && nqp::istype(obj, Iterable)
            ?? obj
            !! obj.list;

    my \result := class :: does SlippyIterator {
        has &!block;
        has $!source;

        method new(&block, $source) {
            my $iter := self.CREATE;
            nqp::bindattr($iter, self, '&!block', &block);
            nqp::bindattr($iter, self, '$!source', $source);
            $iter
        }

        method is-lazy() {
            $!source.is-lazy
        }
        method pull-one() is rw {
            my int $redo = 1;
            my $value;
            my $result;
            if $!slipping && ($result := self.slip-one()) !=:= IterationEnd {
                $result
            }
            elsif ($value := $!source.pull-one()) =:= IterationEnd {
                $value
            }
            else {
                nqp::while(
                    $redo,
                    nqp::stmts(
                        $redo = 0,
                        nqp::handle(
                            nqp::stmts(
                                nqp::if(
                                    nqp::istype($value, Iterable),
                                    nqp::stmts(
                                        ($result := deepmap(&!block, $value).item),
                                    ),
                                    ($result := &!block($value)),
                                ),
                                nqp::if(
                                    nqp::istype($result, Slip),
                                    nqp::stmts(
                                        ($result := self.start-slip($result)),
                                        nqp::if(
                                            nqp::eqaddr($result, IterationEnd),
                                            nqp::stmts(
                                                ($value := $!source.pull-one()),
                                                ($redo = 1 unless nqp::eqaddr($value, IterationEnd))
                                        ))
                                    ))
                            ),
                            'NEXT', nqp::stmts(
                                ($value := $!source.pull-one()),
                                nqp::eqaddr($value, IterationEnd)
                                    ?? ($result := IterationEnd)
                                    !! ($redo = 1)),
                            'REDO', $redo = 1,
                            'LAST', ($result := IterationEnd))),
                    :nohandler);
                $result
            }
        }
    }.new(op, iterable.iterator);

    my $type = nqp::istype(obj, List) ?? obj.WHAT !! List; # keep subtypes of List
    my \buffer := IterationBuffer.new;
    result.push-all(buffer);
    my \retval = $type.new;
    nqp::bindattr(retval, List, '$!reified', buffer);
    nqp::iscont(obj) ?? retval.item !! retval;
}

multi sub deepmap(\op, Associative \h) {
    my @keys = h.keys;
    hash @keys Z deepmap(op, h{@keys})
}

proto sub nodemap(|) { * }
multi sub nodemap(\op, \obj) {
    my Mu $rpa := nqp::list();
    my \objs := obj.list;
    # as a wanted side-effect is-lazy reifies the list
    fail X::Cannot::Lazy.new(:action('deepmap')) if objs.is-lazy;
    my Mu $items := nqp::getattr(objs, List, '$!reified');
    my Mu $o;
    # We process the elements in two passes, end to start, to
    # prevent users from relying on a sequential ordering of hyper.
    # Also, starting at the end pre-allocates $rpa for us.
    my int $i = nqp::elems($items) - 1;
    nqp::while(
        nqp::isge_i($i, 0),
        nqp::stmts(
            ($o := nqp::atpos($items, $i)),
            nqp::bindpos($rpa, $i,
                nqp::if(Mu,             # hack cuz I don't understand nqp
                        $o.new(nodemap(op, $o)).item,
                        op.($o))),
            $i = nqp::sub_i($i, 2)
        )
    );
    $i = nqp::elems($items) - 2;
    nqp::while(
        nqp::isge_i($i, 0),
        nqp::stmts(
            ($o := nqp::atpos($items, $i)),
            nqp::bindpos($rpa, $i,
                nqp::if(Mu,             # hack cuz I don't understand nqp
                        $o.new(nodemap(op, $o)).item,
                        op.($o))),
            $i = nqp::sub_i($i, 2)
        )
    );
    nqp::p6bindattrinvres(nqp::create(List), List, '$!reified', $rpa)
}

multi sub nodemap(\op, Associative \h) {
    my @keys = h.keys;
    hash @keys Z nodemap(op, h{@keys})
}

proto sub duckmap(|) { * }
multi sub duckmap(\op, \obj) {
    nodemap(-> \arg { try { op.(arg) } // try { duckmap(op,arg) } }, obj);
}

multi sub duckmap(\op, Associative \h) {
    my @keys = h.keys;
    hash @keys Z duckmap(op, h{@keys})
}

# vim: ft=perl6 expandtab sw=4
