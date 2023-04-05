set syntax_linkage(aggregate-function-invocation) {{expr filter-clause} {}}
set syntax_linkage(alter-table-stmt) {column-def sql-stmt}
set syntax_linkage(analyze-stmt) {{} sql-stmt}
set syntax_linkage(attach-stmt) {expr sql-stmt}
set syntax_linkage(begin-stmt) {{} sql-stmt}
set syntax_linkage(column-constraint) {{conflict-clause expr foreign-key-clause literal-value signed-number} column-def}
set syntax_linkage(column-def) {{column-constraint type-name} {alter-table-stmt create-table-stmt}}
set syntax_linkage(column-name-list) {{} {update-stmt update-stmt-limited upsert-clause}}
set syntax_linkage(comment-syntax) {{} {}}
set syntax_linkage(commit-stmt) {{} sql-stmt}
set syntax_linkage(common-table-expression) {select-stmt {compound-select-stmt delete-stmt delete-stmt-limited factored-select-stmt insert-stmt select-stmt simple-select-stmt update-stmt update-stmt-limited}}
set syntax_linkage(compound-operator) {{} {factored-select-stmt select-stmt}}
set syntax_linkage(compound-select-stmt) {{common-table-expression expr ordering-term select-core} {}}
set syntax_linkage(conflict-clause) {{} {column-constraint table-constraint}}
set syntax_linkage(create-index-stmt) {{expr indexed-column} sql-stmt}
set syntax_linkage(create-table-stmt) {{column-def select-stmt table-constraint table-options} sql-stmt}
set syntax_linkage(create-trigger-stmt) {{delete-stmt expr insert-stmt select-stmt update-stmt} sql-stmt}
set syntax_linkage(create-view-stmt) {select-stmt sql-stmt}
set syntax_linkage(create-virtual-table-stmt) {{} sql-stmt}
set syntax_linkage(cte-table-name) {{} {recursive-cte with-clause}}
set syntax_linkage(delete-stmt) {{common-table-expression expr qualified-table-name returning-clause} {create-trigger-stmt sql-stmt}}
set syntax_linkage(delete-stmt-limited) {{common-table-expression expr ordering-term qualified-table-name returning-clause} sql-stmt}
set syntax_linkage(detach-stmt) {{} sql-stmt}
set syntax_linkage(drop-index-stmt) {{} sql-stmt}
set syntax_linkage(drop-table-stmt) {{} sql-stmt}
set syntax_linkage(drop-trigger-stmt) {{} sql-stmt}
set syntax_linkage(drop-view-stmt) {{} sql-stmt}
set syntax_linkage(expr) {{filter-clause literal-value over-clause raise-function select-stmt type-name} {aggregate-function-invocation attach-stmt column-constraint compound-select-stmt create-index-stmt create-trigger-stmt delete-stmt delete-stmt-limited factored-select-stmt filter-clause frame-spec indexed-column insert-stmt join-constraint ordering-term over-clause result-column returning-clause select-core select-stmt simple-function-invocation simple-select-stmt table-constraint table-or-subquery update-stmt update-stmt-limited upsert-clause window-defn window-function-invocation}}
set syntax_linkage(factored-select-stmt) {{common-table-expression compound-operator expr ordering-term select-core} {}}
set syntax_linkage(filter-clause) {expr {aggregate-function-invocation expr window-function-invocation}}
set syntax_linkage(foreign-key-clause) {{} {column-constraint table-constraint}}
set syntax_linkage(frame-spec) {expr {over-clause window-defn}}
set syntax_linkage(indexed-column) {expr {create-index-stmt table-constraint upsert-clause}}
set syntax_linkage(insert-stmt) {{common-table-expression expr returning-clause select-stmt upsert-clause} {create-trigger-stmt sql-stmt}}
set syntax_linkage(join-clause) {{join-constraint join-operator table-or-subquery} {select-core select-stmt table-or-subquery update-stmt update-stmt-limited}}
set syntax_linkage(join-constraint) {expr join-clause}
set syntax_linkage(join-operator) {{} join-clause}
set syntax_linkage(literal-value) {{} {column-constraint expr}}
set syntax_linkage(numeric-literal) {{} {}}
set syntax_linkage(ordering-term) {expr {compound-select-stmt delete-stmt-limited factored-select-stmt over-clause select-stmt simple-select-stmt update-stmt-limited window-defn}}
set syntax_linkage(over-clause) {{expr frame-spec ordering-term} expr}
set syntax_linkage(pragma-stmt) {pragma-value sql-stmt}
set syntax_linkage(pragma-value) {signed-number pragma-stmt}
set syntax_linkage(qualified-table-name) {{} {delete-stmt delete-stmt-limited update-stmt update-stmt-limited}}
set syntax_linkage(raise-function) {{} expr}
set syntax_linkage(recursive-cte) {cte-table-name {}}
set syntax_linkage(reindex-stmt) {{} sql-stmt}
set syntax_linkage(release-stmt) {{} sql-stmt}
set syntax_linkage(result-column) {expr {select-core select-stmt}}
set syntax_linkage(returning-clause) {expr {delete-stmt delete-stmt-limited insert-stmt update-stmt update-stmt-limited}}
set syntax_linkage(rollback-stmt) {{} sql-stmt}
set syntax_linkage(savepoint-stmt) {{} sql-stmt}
set syntax_linkage(select-core) {{expr join-clause result-column table-or-subquery window-defn} {compound-select-stmt factored-select-stmt simple-select-stmt}}
set syntax_linkage(select-stmt) {{common-table-expression compound-operator expr join-clause ordering-term result-column table-or-subquery window-defn} {common-table-expression create-table-stmt create-trigger-stmt create-view-stmt expr insert-stmt sql-stmt table-or-subquery with-clause}}
set syntax_linkage(signed-number) {{} {column-constraint pragma-value type-name}}
set syntax_linkage(simple-function-invocation) {expr {}}
set syntax_linkage(simple-select-stmt) {{common-table-expression expr ordering-term select-core} {}}
set syntax_linkage(sql-stmt) {{alter-table-stmt analyze-stmt attach-stmt begin-stmt commit-stmt create-index-stmt create-table-stmt create-trigger-stmt create-view-stmt create-virtual-table-stmt delete-stmt delete-stmt-limited detach-stmt drop-index-stmt drop-table-stmt drop-trigger-stmt drop-view-stmt insert-stmt pragma-stmt reindex-stmt release-stmt rollback-stmt savepoint-stmt select-stmt update-stmt update-stmt-limited vacuum-stmt} sql-stmt-list}
set syntax_linkage(sql-stmt-list) {sql-stmt {}}
set syntax_linkage(table-constraint) {{conflict-clause expr foreign-key-clause indexed-column} create-table-stmt}
set syntax_linkage(table-options) {{} create-table-stmt}
set syntax_linkage(table-or-subquery) {{expr join-clause select-stmt} {join-clause select-core select-stmt update-stmt update-stmt-limited}}
set syntax_linkage(type-name) {signed-number {column-def expr}}
set syntax_linkage(update-stmt) {{column-name-list common-table-expression expr join-clause qualified-table-name returning-clause table-or-subquery} {create-trigger-stmt sql-stmt}}
set syntax_linkage(update-stmt-limited) {{column-name-list common-table-expression expr join-clause ordering-term qualified-table-name returning-clause table-or-subquery} sql-stmt}
set syntax_linkage(upsert-clause) {{column-name-list expr indexed-column} insert-stmt}
set syntax_linkage(vacuum-stmt) {{} sql-stmt}
set syntax_linkage(window-defn) {{expr frame-spec ordering-term} {select-core select-stmt window-function-invocation}}
set syntax_linkage(window-function-invocation) {{expr filter-clause window-defn} {}}
set syntax_linkage(with-clause) {{cte-table-name select-stmt} {}}
set syntax_order {aggregate-function-invocation alter-table-stmt analyze-stmt attach-stmt begin-stmt column-constraint column-def column-name-list comment-syntax commit-stmt common-table-expression compound-operator compound-select-stmt conflict-clause create-index-stmt create-table-stmt create-trigger-stmt create-view-stmt create-virtual-table-stmt cte-table-name delete-stmt delete-stmt-limited detach-stmt drop-index-stmt drop-table-stmt drop-trigger-stmt drop-view-stmt expr factored-select-stmt filter-clause foreign-key-clause frame-spec indexed-column insert-stmt join-clause join-constraint join-operator literal-value numeric-literal ordering-term over-clause pragma-stmt pragma-value qualified-table-name raise-function recursive-cte reindex-stmt release-stmt result-column returning-clause rollback-stmt savepoint-stmt select-core select-stmt signed-number simple-function-invocation simple-select-stmt sql-stmt sql-stmt-list table-constraint table-options table-or-subquery type-name update-stmt update-stmt-limited upsert-clause vacuum-stmt window-defn window-function-invocation with-clause}
