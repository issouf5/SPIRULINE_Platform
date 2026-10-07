
import test from 'node:test';
import assert from 'node:assert/strict';
import {priceToMinor,lineTotal,csv,kg,money} from '../src/utils.js';
test('prix EUR en centimes',()=>assert.equal(priceToMinor('12.34','EUR'),1234));
test('prix XOF sans centimes',()=>assert.equal(priceToMinor('1200','XOF'),1200));
test('quantité fractionnaire de kilogramme',()=>assert.equal(lineTotal(250,1234),309));
test('prix nul autorisé',()=>assert.equal(priceToMinor('0','EUR'),0));
test('prix vides et invalides rejetés',()=>{for(const v of ['',null,undefined,-1,'abc',Infinity])assert.throws(()=>priceToMinor(v,'EUR'));});
test('limite serveur respectée',()=>assert.throws(()=>priceToMinor(100001,'EUR')));
test('CSV protège les formules',()=>{for(const x of ['=1+1','+SUM(A1)','@SUM(A1)','-1','  =cmd'])assert.ok(csv([[x]]).includes("'"+x));});
test('CSV échappe guillemets et retours',()=>assert.equal(csv([['a"b','c\nd']]),'\ufeff"a""b";"c\nd"'));
test('grammes affichés en kg',()=>assert.equal(kg(1250),'1,25 kg'));
test('montant EUR formaté',()=>assert.ok(money(1234,'EUR').includes('12,34')));
