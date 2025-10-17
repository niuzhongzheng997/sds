import pandas as pd

def simple_auto_merge(main_file: str, other_files: list, output_file: str = None):
    """
    最简单的自动合并函数
    """
    # 读取主文件
    df = pd.read_csv(main_file)
    print(f"主文件: {len(df)} 行")
    
    # 依次合并其他文件
    for file in other_files:
        df_other = pd.read_csv(file)
        
        # 自动找共同列
        common_cols = list(set(df.columns) & set(df_other.columns))
        if common_cols:
            df = pd.merge(df, df_other, on=common_cols, how='left')
            print(f"合并 {file}: 新增 {len(df_other.columns) - len(common_cols)} 列")
    
    print(f"最终结果: {len(df)} 行, {len(df.columns)} 列")
    
    if output_file:
        df.to_csv(output_file, index=False)
        print(f"保存到: {output_file}")
    
    return df

# 使用示例
if __name__ == "__main__":
    # 只需修改这3个变量
    main_file = "A.csv"
    other_files = ["B.csv", "C.csv", "D.csv", "E.csv"]
    output_file = "merged_result.csv"
    
    result = simple_auto_merge(main_file, other_files, output_file)
