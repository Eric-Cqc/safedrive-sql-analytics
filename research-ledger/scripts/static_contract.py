"""Limited field-reference lint for CHECK clauses; not a SQL parser or engine."""
import re

KEYWORDS = {'AND','OR','NOT','IS','NULL','ROUND','IF','CASE','WHEN','THEN','ELSE','END','BETWEEN'}

def check_schema(source: str) -> int:
    tables = re.findall(r'CREATE TABLE\s+`?(\w+)`?\s*\((.*?)\) ENGINE\s*=\s*InnoDB;', source, re.S)
    assert len(tables)==11, 'Expected eleven table declarations'
    names=[]
    for table, body in tables:
        columns=set(re.findall(r'^\s{4}`?(\w+)`?\s+(?:INT|VARCHAR|TEXT|ENUM|DATETIME|DECIMAL|YEAR)\b',body,re.M))
        names.extend(re.findall(r'CONSTRAINT\s+(\w+)',body))
        for found in re.finditer(r'CHECK\s*\(',body):
            start=found.end();depth=1;end=start
            while depth and end<len(body):
                depth+=(body[end]=='(')-(body[end]==')');end+=1
            assert depth==0, f'{table}: unbalanced CHECK'
            expr=re.sub(r"'[^']*'",'',body[start:end-1])
            refs={x for x in re.findall(r'[A-Za-z_]\w*',expr) if x.upper() not in KEYWORDS}
            assert refs<=columns, f'{table}: CHECK references undeclared columns {refs-columns}'
    assert len(names)==len(set(names)), 'Duplicate named constraints'
    return len(tables)
