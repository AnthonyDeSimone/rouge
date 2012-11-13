;; -*- mode: clojure; -*-

(ns ^{:doc "The Rouge core."
      :author "Arlen Christian Mart Cuss"}
  rouge.core
  (:use ruby))

(def seq (fn rouge.core/seq [coll]
           (.seq Rouge.Seq coll)))

(def concat (fn rouge.core/concat [& lists]
              ; XXX lazy seq
              (seq (.inject (.to_a (.map lists | .to_a)) | .+))))

(def list (fn rouge.core/list [& elements]
            elements))

(defmacro defn [name args & body]
  (let [fn-name (.intern (.join [(.name (.ns (context))) (.name name)] "/"))]
    `(def ~name (fn ~(Rouge.Symbol. fn-name) ~args ~@body))))

(defmacro when [cond & body]
  `(if ~cond
     (do
       ~@body)))

(defn vector [& args]
  (.to_a args))

(defn reduce [f coll]
  (.inject (.to_a coll) | f))

(defmacro when [cond & body]
  `(if ~cond
     (do
       ~@body)))

(defn map [f coll]
  ; XXX lazy seq
  (.map coll | f))

(defn str [& args]
  (let [args (.to_a (map .to_s args))]
    (.join args "")))

(defn pr-str [& args]
  (let [args (.to_a (map #(.print Rouge % (String.)) args))]
    (.join args " ")))

(defn print [& args]
  (.print Kernel (apply pr-str args)))

(defn puts [& args]
  (.print Kernel (apply str args) "\n"))

(defn count [coll]
  (.length coll))

(defn or [& exprs]
  ; XXX NOT SHORT CIRCUITING!
  (.find (.to_a exprs) | [e] e))

(defn and [& exprs]
  ; XXX NOT SHORT CIRCUITING!
  ; Also not Clojurish: doesn't return falsey value find.
  (if (.all? (.to_a exprs) | [e] e)
    (.last (.to_a exprs))))

(defn class [object]
  (.class object))

(defn sequential? [coll]
  (or (.is_a? coll Rouge.Seq.ISeq)
      (.is_a? coll Array)))

(defn = [a b]
  (let [pre (if (and (sequential? a)
                     (sequential? b))
              seq
              #(do %))]
    (.== (pre a) (pre b))))

(defn not [bool]
  (or (= bool nil)
      (= bool false)))

(defn empty? [coll]
  (= 0 (count coll)))

(defn + [& args]
  (if (empty? args)
    0
    (reduce .+ args)))

(defn - [a & args]
  (reduce .- (concat (list a) args)))

(defn * [& args]
  (if (empty? args)
    1
    (reduce .* args)))

(defn / [a & args]
  (reduce ./ (concat (list a) args)))

(defn require [lib]
  (.require Kernel lib))

(defn cons [head tail]
  ; XXX lazy seq
  (Rouge.Seq.Cons. head tail))

(defn range [from til]
  ; XXX this will blow so many stacks
  (if (= from til)
    Rouge.Seq.Empty
    (cons from (range (+ 1 from) til))))

(defn seq? [object]
  (or (= (class object) Rouge.Seq.Cons)
      (= object Rouge.Seq.Empty)))

(def *ns* 'user) ; XXX what

(defn ns-publics [ns]
  )

(defn nth [coll index]
  (.[] (seq coll) index))

(defn first [coll]
  (.first (seq coll)))

(defn rest [coll]
  (.more (seq coll)))

(defn next [coll]
  (.next (seq coll)))

(defn second [coll]
  (first (next coll)))

(defn > [a b]
  (.> a b))

(defn < [a b]
  (.< a b))

(defmacro macroexpand [form]
  `(.compile Rouge.Compiler (.ns (context)) (Set.) ~form))

(defn push-thread-bindings [map]
  (.push Rouge.Var map))

(defn pop-thread-bindings []
  (.pop Rouge.Var))

(defn hash-map [& keyvals]
  (apply .[] Hash keyvals))

(defmacro binding [bindings & body]
  (let [var-ize (fn [var-vals]
                  (.flatten
                    (map
                      (fn [pair]
                        (let [key (first pair)
                              val (second pair)]
                          [`(.name (var ~key)) val]))
                      (.each_slice var-vals 2))
                    1))]
  `(try
     (push-thread-bindings (hash-map ~@(var-ize bindings)))
     ~@body
     (finally
       (pop-thread-bindings)))))

(defn deref [derefable]
  (.deref derefable))

(defn atom [initial]
  (Rouge.Atom. initial))

(defn swap! [atom f & args]
  (apply .swap! atom f args))

(defn inc [v]
  (+ v 1))

(defn dec [v]
  (- v 1))

(defn conj [coll & xs]
  ; only cons and vector.  Also SUCKS.
  (if (= 0 (count xs))
    coll
    (let [c (class coll)
          hd (first xs)
          tl (rest xs)]
      (if (= c Rouge.Seq.Cons)
        (apply conj (Rouge.Seq.Cons coll hd) tl)
        (apply conj (.push (.dup coll) hd) tl)))))

(defn get [map key] ; and [map key not-found]
  (.[] map key))

(defn meta [x]
  ; TODO
  nil)

(defn with-meta [x m]
  ; TODO
  x)

(defmacro .
  [recv method & args]
  `(.send ~recv ~(.name method) ~@args))

(defmacro ->
  ; (-> x) => x
  ([x] x)
  ; (-> e (a b)) => (a e b)
  ; (-> e a) => (a e)
  ([x f]
   (if (seq? f)
     `(~(first f) ~x ~@(rest f))
     `(~f ~x)))
  ([x f & rest]
   `(-> (-> ~x ~f) ~@rest)))


(ns rouge.test
  (:use rouge.core ruby))

(def ^:dynamic *test-level* [])
(def *tests-passed* (atom 0))
(def *tests-failed* (atom []))

(defmacro testing [what & tests]
  `(do
     (when (= [] *test-level*)
       (puts))
     (puts (* " " (count *test-level*) 2) "testing: " ~what)
     (binding [*test-level* (conj *test-level* ~what)]
       ~@tests
       {:passed @*tests-passed*
        :failed @*tests-failed*})))

(defmacro is [check]
  `(let [result# (try
                  {:error nil, :result ~check}
                  (catch Exception e#
                    {:error e#, :result false}))]
     (if (not (get result# :result))
      (do
        (swap! *tests-failed* conj (conj *test-level* (pr-str '~check)))
        (puts "FAIL in ???")
        (puts "expected: " ~(pr-str check))
        (let [actual#
                (let [error# (get result# :error)]
                  (if error#
                    error#
                    (if (and (seq? '~check)
                             (= 'not (first '~check)))
                      (second '~check)
                      `(not ~'~check))))]
          (puts "  actual: " (pr-str actual#))))
      (do
        (swap! *tests-passed* inc)
        true))))

(defmacro pending [& body]
  (puts "TODO rouge.test/pending"))

; vim: set ft=clojure cc=80:
