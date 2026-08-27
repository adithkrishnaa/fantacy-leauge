const express = require("express");
const { addTransaction, getTransactionsByUser, deleteTransaction } = require("../controllers/TransactionController");
const { protect, admin } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/", protect, admin, addTransaction);
router.get("/:userId", protect, getTransactionsByUser);
router.delete("/:id", protect, admin, deleteTransaction);

module.exports = router;
