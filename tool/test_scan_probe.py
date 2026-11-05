import unittest

from scan_probe import evaluate


def result(name, metadata):
    return {"nome": name, "risultato": {"items": [{"metadata": metadata, "dubbi": []}]}}


class EvaluationTests(unittest.TestCase):
    def test_rejects_wrong_warmth_from_real_regression(self):
        records = [result("Calzini", {"category": "Essentials", "subCategory": "Socks", "warmth": 3})]
        errors = evaluate(records, {"Calzini": {"expected": {"warmth": 1}}})
        self.assertEqual(errors, ["Calzini: warmth diverso dall'atteso"])

    def test_unlisted_garment_must_not_become_non_clothing(self):
        case = {"Costume da carnevale": {"forbidden": {"category": ["Not Clothing"]}}}
        self.assertTrue(evaluate([result("Costume da carnevale", {"category": "Not Clothing"})], case))
        self.assertEqual(evaluate([result("Costume da carnevale", {"category": "Full Body", "subCategory": "Other"})], case), [])
        self.assertTrue(evaluate([], case))


if __name__ == "__main__":
    unittest.main()
