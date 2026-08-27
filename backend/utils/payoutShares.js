const calculateHouseShares = (remainingAmount, adminWeight, managerWeight) => {
  if (remainingAmount <= 0) return { adminShare: 0, managerShare: 0 };
  const admin = Number(adminWeight);
  const manager = Number(managerWeight);
  if (!Number.isFinite(admin) || !Number.isFinite(manager) || admin < 0 || manager < 0 || admin + manager <= 0) {
    const error = new Error('Admin and Manager share weights must be configured');
    error.statusCode = 400;
    throw error;
  }
  const adminShare = remainingAmount * admin / (admin + manager);
  return { adminShare, managerShare: remainingAmount - adminShare };
};

module.exports = { calculateHouseShares };
